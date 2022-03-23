package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"contrib.go.opencensus.io/exporter/prometheus"
	"go.opencensus.io/stats"
	"go.opencensus.io/stats/view"
	"go.opencensus.io/tag"

	promclient "github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/push"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/multiformats/go-multihash"
	"github.com/multiformats/go-varint"
	"golang.org/x/time/rate"
)

type LoadGenConfig struct {
	// Frequency specifies the number of requests per second
	Frequency float64 `json:"frequency"`
	// Concurrency specifies the number of concurrent requests
	Concurrency int `json:"concurrency"`
	// DurationSeconds specifies the total duration of the load test
	DurationSeconds    int    `json:"durationSeconds"`
	MaxProviderSeed    int    `json:"maxProviderSeed"`
	MaxEntryNumber     int    `json:"maxEntryNumber"`
	IndexerEndpointUrl string `json:"indexerEndpointUrl"`
	MetricsPushGateway string `json:"metricsPushGateway"`
}

var instanceID int64

func init() {
	rand.Seed(time.Now().UnixNano())
	instanceID = rand.Int63()
}

var FindLatency = stats.Float64("find/latency", "Time to respond to a find request", stats.UnitMilliseconds)
var StatusCode, _ = tag.NewKey("statusCode")
var Instance, _ = tag.NewKey("instance")
var findLatencyView = &view.View{
	Measure:     FindLatency,
	Aggregation: view.Distribution(0, 1, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 200, 300, 400, 500, 1000, 2000, 5000),
	TagKeys:     []tag.Key{StatusCode, Instance},
}

func registerMetrics() *promclient.Registry {
	view.Register(findLatencyView)

	registry, ok := promclient.DefaultRegisterer.(*promclient.Registry)
	if !ok {
		fmt.Printf("failed to export default prometheus registry; some metrics will be unavailable; unexpected type: %T\n", promclient.DefaultRegisterer)
	}
	return registry
}

type pushGatewayRegisterer struct {
	url         string
	serviceName string
	pusher      *push.Pusher
}

func (r *pushGatewayRegisterer) Register(c promclient.Collector) error {
	r.pusher = push.New(r.url, r.serviceName).Collector(c)
	return nil
}

func (r *pushGatewayRegisterer) MustRegister(cs ...promclient.Collector) {
	err := r.Register(cs[0])
	if err != nil {
		panic(err)
	}
}
func (r *pushGatewayRegisterer) Unregister(c promclient.Collector) bool {
	return false
}

func pushMetrics(ctx context.Context, cfg *LoadGenConfig) func() {
	if cfg.MetricsPushGateway == "" {
		return func() {}
	}

	registry := registerMetrics()

	os.Hostname()
	serviceName := "read_load_generator_" + fmt.Sprint(instanceID)
	namespace := "read_load_generator"
	fmt.Println("ID", instanceID)
	p := &pushGatewayRegisterer{serviceName: serviceName, url: cfg.MetricsPushGateway}
	_, err := prometheus.NewExporter(prometheus.Options{
		Registry:   registry,
		Namespace:  namespace,
		Registerer: p,
	})
	if err != nil {
		panic("Failed to create exporter")
	}

	closeCh := make(chan struct{})
	wg := &sync.WaitGroup{}
	closeFn := func() {
		close(closeCh)
		wg.Wait()
	}

	wg.Add(1)
	go func() {
		ticker := time.NewTicker(2 * time.Second)
		for {
			select {
			case <-closeCh:
				fmt.Println("Pushing metrics")
				p.pusher.Push()
				wg.Done()
				return
			case <-ticker.C:
				fmt.Println("Pushing metrics")
				p.pusher.Push()
			}
		}
	}()

	return closeFn
}

func HandleRequest(ctx context.Context, cfg LoadGenConfig) (string, error) {
	dur := time.Second * time.Duration(cfg.DurationSeconds)
	ctx, cancel := context.WithTimeout(ctx, dur)
	defer cancel()

	fmt.Println("Starting load test")
	closePushMetrics := pushMetrics(ctx, &cfg)
	defer closePushMetrics()

	allErrsCh := make(chan []error, cfg.Concurrency)

	wg := &sync.WaitGroup{}
	for i := 0; i < cfg.Concurrency; i++ {
		wg.Add(1)
		go func(id int) {
			errs := worker(ctx, id, &cfg)
			allErrsCh <- errs
			wg.Done()
		}(i)
	}

	wg.Wait()
	close(allErrsCh)
	fmt.Println("Done with load test")

	var allErrs []error
	for errs := range allErrsCh {
		allErrs = append(allErrs, errs...)
	}

	var filteredErrs []error
	var randErr error
	var missingErrs int
	if len(allErrs) > 0 {
		for _, err := range allErrs {
			if strings.Contains(err.Error(), "missing multihash") {
				missingErrs++
			} else {
				filteredErrs = append(filteredErrs, err)
			}
		}
		if filteredErrs != nil {
			randErr = filteredErrs[rand.Intn(len(filteredErrs))]
		}
	}

	return fmt.Sprintf("Missed %d mhs. Ran into %d errs. Random err: %v", missingErrs, len(filteredErrs), randErr), nil
}

func worker(ctx context.Context, id int, cfg *LoadGenConfig) []error {
	l := rate.NewLimiter(rate.Limit(cfg.Frequency), 1)
	c := &http.Client{}
	var errs []error
	for {
		err := l.Wait(ctx)
		if err != nil {
			return errs
		}

		err = load(ctx, id, c, cfg)
		if err != nil {
			errs = append(errs, err)
		}
	}
}

func find(ctx context.Context, c *http.Client, url string, m multihash.Multihash) (*http.Response, error) {
	u := fmt.Sprint(url, "/multihash/", m.B58String())
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return nil, err
	}

	req.Header.Set("Content-Type", "application/json")
	return c.Do(req)
}

func load(ctx context.Context, workerID int, c *http.Client, cfg *LoadGenConfig) error {

	randomProviderSeed := rand.Intn(cfg.MaxProviderSeed) + 1
	randomEntryNumber := rand.Intn(cfg.MaxEntryNumber)
	mh, err := generateMH(uint64(randomProviderSeed), uint64(randomEntryNumber))
	if err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(ctx, time.Second/time.Duration(cfg.Frequency))
	defer cancel()
	start := time.Now()
	var resp *http.Response
	defer func() {
		statusCode := 0
		if resp != nil {
			statusCode = resp.StatusCode
		}
		msSinceStart := time.Since(start).Milliseconds()
		stats.RecordWithOptions(context.Background(),
			stats.WithTags(
				tag.Insert(StatusCode, fmt.Sprintf("%v", statusCode)),
				tag.Insert(Instance, fmt.Sprintf("%v", instanceID)),
			),
			stats.WithMeasurements(FindLatency.M(float64(msSinceStart))))
	}()
	resp, err = find(ctx, c, cfg.IndexerEndpointUrl, mh)
	if err != nil {
		return err
	}

	if resp.StatusCode == http.StatusNotFound {
		return fmt.Errorf("missing multihash for entryNumber=%v on provider=%v", randomEntryNumber, randomProviderSeed)
	}

	return nil
}

func main() {
	_, ok := os.LookupEnv("LOCAL_DEBUG")
	if ok {
		b, err := io.ReadAll(os.Stdin)
		if err != nil {
			panic(err)
		}
		var cfg LoadGenConfig
		err = json.Unmarshal(b, &cfg)
		if err != nil {
			panic(err)
		}
		fmt.Println(HandleRequest(context.Background(), cfg))
		return
	}
	lambda.Start(HandleRequest)
}

func generateMH(nodeID uint64, entryNumber uint64) (multihash.Multihash, error) {
	nodeIDVarInt := varint.ToUvarint(nodeID)
	nVarInt := varint.ToUvarint(entryNumber)
	b := append(nodeIDVarInt, nVarInt...)

	return multihash.Sum(b, multihash.SHA2_256, -1)
}
