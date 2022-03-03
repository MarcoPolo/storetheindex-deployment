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
