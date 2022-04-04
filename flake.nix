{
  description = "A very basic flake";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/release-21.11";
  inputs.deploy-rs = {
    url = "github:serokell/deploy-rs";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.storetheindex-src = {
    url = "github:filecoin-project/storetheindex";
    flake = false;
  };

  inputs.nix-prefetch = {
    url = "github:ShamrockLee/nix-prefetch/experimental-features";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.flake-utils.follows = "flake-utils";
  };

  outputs = { self, nixpkgs, deploy-rs, flake-utils, storetheindex-src, nix-prefetch }:
    let
      ssh-key-path = "~/.ssh/marco-storetheindex-deployment";
      tf-output =
        let
          file-path = ./terraform-output.json;
          file-contents = if builtins.pathExists file-path then builtins.readFile file-path else "";
          firstChar = builtins.substring 0 1 file-contents;
        in
        if firstChar == "{" then
          (builtins.fromJSON file-contents)
        else
          { };
      deployerIP = (tf-output.deployerIP.value or "0.0.0.0");
      indexerIP = (tf-output.indexerIP.value or "0.0.0.0");
      indexer2IP = (tf-output.indexer2IP.value or "0.0.0.0");
      gammazeroIndexerIP = (tf-output.gammazeroIndexerIP.value or "0.0.0.0");
    in
    {
      deploy.nodes = {
        indexer = {
          hostname = indexerIP;
          profiles.system = {
            user = "root";
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.indexer;
          };
        };
        indexer2 = {
          hostname = indexer2IP;
          profiles.system = {
            user = "root";
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.indexer;
          };
        };
        # gammazeroIndexer = {
        #   hostname = gammazeroIndexerIP;
        #   profiles.system = {
        #     user = "root";
        #     path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.indexer;
        #   };
        # };
        deployer = {
          hostname = (builtins.fromJSON (builtins.readFile ./terraform-output.json)).deployerIP.value;
          profiles.system = {
            user = "root";
            sshUser = "root";
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.deployer;
          };
        };
      };
      nixosConfigurations = {
        indexer = nixpkgs.lib.nixosSystem
          {
            system = "x86_64-linux";
            modules = [
              ./indexer.nix
              {
                environment.systemPackages =
                  with self.packages."x86_64-linux";
                  [ storetheindex provider-load-gen ];
              }
            ];
          };
        deployer = nixpkgs.lib.nixosSystem
          {
            system = "x86_64-linux";
            modules = [
              ./deployer.nix
              (import ./metrics.nix { inherit indexerIP indexer2IP gammazeroIndexerIP; })
              {
                environment.systemPackages =
                  with self.packages."x86_64-linux";
                  [ storetheindex provider-load-gen ];
              }
            ];
          };
      };
    } //
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs { system = system; };
          jq = "${pkgs.jq}/bin/jq";
          update-terraform-output = pkgs.writeScriptBin "update-terraform-output"
            ''
              tmpfile=$(mktemp)

              # Remove any sensitive output
              ${self.packages.${system}.terraform}/bin/terraform output -json |  ${jq} 'with_entries( select(.value | .sensitive == false ) )' > "$tmpfile"
              # Is there an update?
              if ! cmp terraform-output.json "$tmpfile" >/dev/null 2>&1
              then
                mv $tmpfile terraform-output.json
              fi

              cat terraform-output.json
            '';
          rsync-to-deployer = pkgs.writeScriptBin "rsync-to-deployer"
            ''
              if [[ -z "''${OVERRIDE_DEPLOYER_IP}" ]]; then
                deployerIP=$(update-terraform-output | ${jq} -r .deployerIP.value)
              else
                deployerIP=$OVERRIDE_DEPLOYER_IP
              fi
              ${pkgs.rsync}/bin/rsync -e 'ssh -o StrictHostKeyChecking=accept-new -i ${ssh-key-path}' -azP --delete --filter=":- .gitignore" --exclude=".direnv" --exclude='.git*' . root@$deployerIP:~/storetheindex-deployment
            '';
          ssh-to-deployer = pkgs.writeScriptBin "ssh-to-deployer"
            ''
              if [[ -z "''${OVERRIDE_DEPLOYER_IP}" ]]; then
                deployerIP=$(update-terraform-output | ${jq} -r .deployerIP.value)
              else
                deployerIP=$OVERRIDE_DEPLOYER_IP
                echo "Using override deployerIP: $deployerIP"
              fi
              ssh -o StrictHostKeyChecking=accept-new -i ${ssh-key-path} root@$deployerIP $@
            '';
          # Special case where we are still bootstrapping during terraform apply
          deploy-first-time = pkgs.writeScriptBin "deploy-first-time"
            ''
              cat <<EOF > terraform-output.json
              {
                "deployerIP": {
                  "sensitive": false,
                  "type": "string",
                  "value": "$1"
                }
              }
              EOF
              OVERRIDE_DEPLOYER_IP=$1 ${rsync-to-deployer}/bin/rsync-to-deployer;
              OVERRIDE_DEPLOYER_IP=$1 ${ssh-to-deployer}/bin/ssh-to-deployer "cd storetheindex-deployment && nix run .  -- -s .#deployer --ssh-opts='-o StrictHostKeyChecking=accept-new' --hostname '127.0.0.1'";
            '';
          deploy-on-deployer = pkgs.writeScriptBin "deploy-on-deployer"
            ''
              ${rsync-to-deployer}/bin/rsync-to-deployer;
              ${ssh-to-deployer}/bin/ssh-to-deployer "cd storetheindex-deployment && nix develop --command deploy -s $@";
            '';
          check-fingerprints = pkgs.writeScriptBin "check-fingerprints"
            ''
              echo "Checking fingerprints..."
              for IP in $(${update-terraform-output}/bin/update-terraform-output | ${jq} '.[] | .value')
              do
                echo "Trying to connect to $IP from the deployer node"
                ${ssh-to-deployer}/bin/ssh-to-deployer -t ssh $IP echo ok
              done
            '';
        in
        {
          packages.update-vendor-sha = pkgs.writeScriptBin "update-vendor-sha" ''
            set -euo pipefail
            cd $(git rev-parse --show-toplevel)

            echo "Updating read load generator vendorSha"
            newSha=$(nix-prefetch \
               '{ sha256 }: (builtins.getFlake (toString ./.)).packages.${system}.read-load-gen.go-modules.overrideAttrs (_: { vendorSha256 = sha256; })' \
               --output nix)
            echo "# Autogenerated by update-vendor-sha script. Do not edit." > ./load-testing-tools/read-load-generator/vendorSha.nix
            echo $newSha >> ./load-testing-tools/read-load-generator/vendorSha.nix

            echo "Updating provider load generator vendorSha"
            newSha=$(nix-prefetch \
               '{ sha256 }: (builtins.getFlake (toString ./.)).packages.${system}.provider-load-gen.go-modules.overrideAttrs (_: { vendorSha256 = sha256; })' \
               --output nix)
            echo "# Autogenerated by update-vendor-sha script. Do not edit." > ./load-testing-tools/provider-load-generator/vendorSha.nix
            echo $newSha >> ./load-testing-tools/provider-load-generator/vendorSha.nix

            echo "Updating storetheindex vendorSha"
            newSha=$(nix-prefetch \
               '{ sha256 }: (builtins.getFlake (toString ./.)).packages.${system}.storetheindex.go-modules.overrideAttrs (_: { vendorSha256 = sha256; })' \
               --output nix)
            echo "# Autogenerated by update-vendor-sha script. Do not edit." > ./storetheindex/vendorSha.nix
            echo $newSha >> ./storetheindex/vendorSha.nix
          '';
          packages.invoke-read-load-gen = pkgs.writeScriptBin "invoke-read-load-gen" ''
            # Reads config from stdin

            # Example
            # CONCURRENT_REQS=3 invoke-read-load-gen < load-testing-tools/read-load-generator/example-configs/minimal.json

            echo "Concurrent requests: $CONCURRENT_REQS"

            cd $(git rev-parse --show-toplevel)
            payload=$(${pkgs.coreutils}/bin/base64 -w 0 <&0)
            functionArn=$(${pkgs.terraform_0_14}/bin/terraform output -json | ${jq} -r '.["read-load-gen-lambda-arn"].value')

            for i in $(seq 1 $CONCURRENT_REQS);
            do
              echo "request: $i";
              tmpfile=$(mktemp)
              (${pkgs.awscli2}/bin/aws \
                --region us-west-2 \
                --profile storetheindex \
                lambda invoke \
                --invocation-type "Event" \
                --function-name "$functionArn" \
                --payload $payload \
                "$tmpfile" && (
                  cat $tmpfile;
                  rm $tmpfile;
                )) &

            done


            for job in `jobs -p`
            do
            echo $job
                wait $job
            done
          '';
          packages.terraform = pkgs.terraform_0_14;
          packages.storetheindex = pkgs.callPackage ./storetheindex { src = storetheindex-src; };
          packages.provider-load-gen = pkgs.callPackage ./load-testing-tools/provider-load-generator { };
          packages.read-load-gen = pkgs.callPackage ./load-testing-tools/read-load-generator { };
          packages.read-load-gen-container-with-pkgs = { pkgs }: (
            pkgs.dockerTools.buildLayeredImage {
              name = "storetheindex-read-load-gen";
              tag = "latest";

              contents = [
                pkgs.cacert
                (pkgs.callPackage
                  ./load-testing-tools/read-load-generator
                  { })
              ];
              config = {
                Cmd = [ "/bin/read-load-generator" ];
              };
            }
          );
          packages.read-load-gen-arm-container = self.packages.${system}.read-load-gen-container-with-pkgs {
            pkgs = import nixpkgs {
              inherit system;
              crossSystem = { config = "aarch64-unknown-linux-gnu"; };
            };
          };
          packages.read-load-gen-container = self.packages.${system}.read-load-gen-container-with-pkgs { pkgs = import nixpkgs { inherit system; }; };
          packages.build-and-fetch-load-gen-container = pkgs.writeScriptBin "build-and-fetch-load-gen-container" ''
            set -euo pipefail
            deployerIP=$(${pkgs.terraform_0_14}/bin/terraform output -json | ${jq} -r '.["deployerIP"].value')

            # Have the deployer build the arm container
            containerPath=$(ssh root@$deployerIP "cd storetheindex-deployment && nix build .#read-load-gen-arm-container --no-link --json" | ${jq} -r '.[0].outputs.out')
            # Then we'll copy the built container locally so that we can give it to our docker.
            nix-copy-closure --from root@${deployerIP} $containerPath
            docker load < $containerPath
          '';
          packages.nix-prefetch = pkgs.callPackage (import "${nix-prefetch}/default.nix") {
            nix = pkgs.nix_2_4;
          };
          packages.deploy-first-time = deploy-first-time;
          defaultApp = deploy-rs.defaultApp.${system};
          devShell = pkgs.mkShell {
            INDEXER_IP = indexerIP;
            INDEXER2_IP = (tf-output.indexer2IP.value or "0.0.0.0");
            GZ_INDEXER_IP = gammazeroIndexerIP;
            DEPLOYER_IP = deployerIP;
            buildInputs = [
              pkgs.awscli2
              self.packages.${system}.terraform
              deploy-rs.defaultPackage.${system}
              update-terraform-output
              rsync-to-deployer
              ssh-to-deployer
              deploy-on-deployer
              check-fingerprints
              pkgs.jq
              pkgs.go_1_17
              self.packages.${system}.nix-prefetch
              self.packages.${system}.update-vendor-sha
              self.packages.${system}.invoke-read-load-gen
              self.packages.${system}.build-and-fetch-load-gen-container
            ];
          };
        });
}
