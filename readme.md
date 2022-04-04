# Quickstart
1. Clone this repo and `cd` into it.
1. Install NixOS: https://nixos.org/download.html
1. Enter the dev environment `nix develop`
1. Setup your AWS cli with a profile called `storetheindex` for the
   storetheindex aws account.
1. Initialize terraform `terraform init`
1. Create a new ssh key for the deployer and to use to connect to these
   instances. Define the location of that key in `variables.tf` and `flake.nix`.
1. Launch the instances of terraform with `terraform apply`
1. Run `check-fingerprints` to have the deployer node learn about the other
   node's public key fingerprints (and you can verify them).
1. Run `deploy-on-deployer` to deploy everything. (It may take a bit on the
   first run since it needs to build the deploy tool before even starting the
   deploy.). Now you have an indexer node that's ready to go.

## Starting the indexer
1. ssh into the indexer with `ssh root@$INDEXER_IP`
1. Start a tmux session with `tmux`. Optional but very useful.
1. Setup the indexer with `storetheindex init --pubsub-topic /indexer/ingest/load-test --listen-admin "/ip4/0.0.0.0/tcp/3002"`
1. Start the indexer process with `storetheindex daemon`

## Starting the provider load generator
1. ssh into the indexer with `ssh root@INDEXER_IP`. (This should work with any
   node, but in this example we're generating load from the same node.)
1. Start the load generator with: `load-testing -config /etc/load-testing-configs/minimal.json`

# Setting up metrics
The deployer also runs Grafana and Prometheus. Login into grafana by going to
http://$DEPLOYER_IP. If this is the first time you're connecting to grafana you
can login with admin/admin, and it'll prompt you to change your password after
your first login.

# Local environment setup
Install [NixOS](https://nixos.org/) and enter the correct with `nix develop`.
Or, optionally, use ([direnv](https://direnv.net/) which sets up your
environment automatically when `cd`ing into this directory.
# Terraform setup
```
terraform init
```
# Launch instances

```
terraform apply
```

# Deploy system configuration

Deploys are run on a remote deployer server. This is for a couple reasons:
1. Deployer runs the same architecture as the target server, so it can build
   everything the target needs locally first.
2. Deployer likely has a much faster network connection to the target server
   than you do locally.

Ideally we could still run the deploy command locally and have the build and
copy happen remotely, but that's [not supported
yet](https://github.com/serokell/deploy-rs/issues/12) by the deploy-rs tool.


Note that an initial deployment to a new server will fail because the deployer
doesn't know to trust the remote server's public key. To check this run
`ssh-to-deployer ssh $INDEXER_IP echo ok`.

Everything:
```
deploy-on-deployer
```

Only some node:
```
deploy-on-deployer .#indexer
```

# Using a different branch of storetheindex

The version of the storetheindex that's deployed on the indexer is defined in
`flake.nix`. If you want to point it to a different branch you can update the
attribute of `inputs.storetheindex-src.url`. To update the referenced value
(branch is the same, but the commit has changed), you can run `nix flake lock
--update-input storetheindex-src`. You may also need to update the
`vendorSha256` if the dependencies change. To do that run the
`update-vendor-sha` command.

Alternatively, you can `git clone` the storetheindex repo on the indexer node
and manually build and run it with `go`.

# Read load generator

1. `terraform apply` will setup the lambda and ECR repo, and push the container
   to the ECR.
1. Invoke the lambda with the `invoke-read-load-gen`. The config is passed in
   via stdin, and it accepts a `CONCURRENT_REQS` environment parameter. For
   example:
   ```
   CONCURRENT_REQS=3 invoke-read-load-gen < load-testing-tools/read-load-generator/example-configs/minimal.json
   ```
   will run invoke 3 concurrent read load generators with the given config.

Note that the workers use a prometheus push gateway to push metrics to
prometheus, which means that the deployer node should be up if you want to see
metrics from the read load generator side.

## Examples

Runnign a read load test with 100 concurrent workers each making 500 concurrent
requests a second (50k rps).

```bash
CONCURRENT_REQS=100 invoke-read-load-gen <<EOF
{
  "frequency": 1,
  "concurrency": 500,
  "durationSeconds": 360,
  "maxProviderSeed": 1000000,
  "maxEntryNumber": 100,
  "metricsPushGateway": "http://44.234.109.29:9091",
  "indexerEndpointUrl": "https://d3pmvzacpjhvv9.cloudfront.net"
}
EOF
```

## Running read load generator locally

If you set the environment variable `LOCAL_DEBUG=1` then the read load generator
will assume it's running locally instead of in a Lambda. You can pass it a
config via stdin. For example:
```
LOCAL_DEBUG=1 go run main.go < ./example-configs/minimal.json
```

## Using heredoc

You can also use a heredoc to specify the config. For example:
```
LOCAL_DEBUG=1 go run main.go <<EOF
{
  "frequency": 10,
  "concurrency": 10,
  "durationSeconds": 1,
  "maxProviderSeed": 10000,
  "maxEntryNumber": 10,
  "metricsPushGateway": "http://44.234.109.29:9091",
  "indexerEndpointUrl": "http://localhost:3000"
}
EOF

```

# Debugging
## Stuck around 1k connections
You may have to restart the indexer to update the soft file limit. To check if
this is the problem run `ulimit -Sn`. If that's ~1k that's the issue. Restarting
it should reload the limit to ~64k.