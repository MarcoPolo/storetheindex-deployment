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

Everything:
```
deploy
```

Only some node:
```
deploy .#node
```


## If deployment machine arch != target machine arch
You can use the remote machine as the builder. Replace the values here with the
current builder's values. You can get the pub key fingerprint by running `base64 -w0 /etc/ssh/ssh_host_ed25519_key.pub`
```
SSH_KEY_PATH=/Users/marco/.ssh/marco-storetheindex-deployment \
BUILDER_IP=35.84.143.136 \
BUILDER_PUB_KEY="c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUYrVUw4YUtmd3IvN0tpU0hWSkxyVFpxSVF5UUFEOENweWpHYXpHazEwTHggcm9vdEBpcC0xNzItMzEtNTktMjMudXMtd2VzdC0yLmNvbXB1dGUuaW50ZXJuYWw0K"; \
deploy --ssh-opts="-i $SSH_KEY_PATH" -s -- .#deployer -j0 \
  --builders "ssh://root@$BUILDER_IP x86_64-linux /Users/marco/.ssh/marco-storetheindex-deployment 4 2 nixos-test,benchmark,big-parallel - $BUILDER_PUB_KEY"
```

## Scratch

```
 nix develop --extra-experimental-features nix-command --extra-experimental-features flakes
```