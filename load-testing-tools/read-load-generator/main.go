package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"math/rand"
	"os"
	"sync"
	"time"

	"github.com/aws/aws-lambda-go/lambda"
	httpfinderclient "github.com/filecoin-project/storetheindex/api/v0/finder/client/http"
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
}

func HandleRequest(ctx context.Context, cfg LoadGenConfig) (string, error) {
	dur := time.Second * time.Duration(cfg.DurationSeconds)
	ctx, cancel := context.WithTimeout(ctx, dur)
	defer cancel()

	fmt.Println("Starting load test")

	allErrsCh := make(chan []error, cfg.Concurrency)

	wg := &sync.WaitGroup{}
	for i := 0; i < cfg.Concurrency; i++ {
		wg.Add(1)
		go func() {
			errs := worker(ctx, &cfg)
			allErrsCh <- errs
			wg.Done()
		}()
	}

	wg.Wait()
	close(allErrsCh)
	fmt.Println("Done with load test")

	var allErrs []error
	for errs := range allErrsCh {
		allErrs = append(allErrs, errs...)
	}

	randErr := allErrs[rand.Intn(len(allErrs))]
	return fmt.Sprintf("Ran into %d errs. Random err %v", len(allErrs), randErr), nil
}

func worker(ctx context.Context, cfg *LoadGenConfig) []error {
	l := rate.NewLimiter(rate.Limit(cfg.Frequency), 1)
	var errs []error
	for {
		err := l.Wait(ctx)
		if err != nil {
			return errs
		}

		err = load(ctx, cfg)
		if err != nil {
			errs = append(errs, err)
		}
	}
}

func load(ctx context.Context, cfg *LoadGenConfig) error {
	client, err := httpfinderclient.New(cfg.IndexerEndpointUrl)
	if err != nil {
		return err
	}

	randomProviderSeed := rand.Intn(cfg.MaxProviderSeed)
	randomEntryNumber := rand.Intn(cfg.MaxEntryNumber)
	mh, err := generateMH(uint64(randomProviderSeed), uint64(randomEntryNumber))
	if err != nil {
		return err
	}

	resp, err := client.Find(context.Background(), mh)
	if err != nil {
		return err
	}

	if len(resp.MultihashResults) == 0 {
		return fmt.Errorf("missing multihash")
	}

	if resp.MultihashResults[0].Multihash.B58String() != mh.B58String() {
		return fmt.Errorf("unexpected multihash")
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
