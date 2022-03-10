# Quickstart
1. Clone this repo and `cd` into it.
1. Install NixOS: https://nixos.org/download.html
1. Enter the dev environment `nix develop`
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
`vendorSha256` if the dependencies change. To do that change it to the fake sha,
the build will fail but it will tell you the expected sha. Update the sha to theo
expected one and it should work on the next build.

Alternatively, you can `git clone` the storetheindex repo on the indexer node
and manually build and run it with `go`.