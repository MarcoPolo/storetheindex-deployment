{
  description = "A very basic flake";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/release-21.11";
  inputs.deploy-rs = {
    url = "github:serokell/deploy-rs";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.storetheindex-src = {
    url = "github:filecoin-project/storetheindex/marco/load-testing";
    flake = false;
  };

  outputs = { self, nixpkgs, deploy-rs, flake-utils, storetheindex-src }:
    let
      ssh-key-path = "~/.ssh/marco-storetheindex-deployment";
      tf-output = builtins.fromJSON (builtins.readFile ./terraform-output.json);
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
              (import ./metrics.nix { inherit indexerIP gammazeroIndexerIP; })
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
          update-terraform-output = pkgs.writeScriptBin "update-terraform-output"
            ''
              tmpfile=$(mktemp)

              # Remove any sensitive output
              ${self.packages.${system}.terraform}/bin/terraform output -json |  ${pkgs.jq}/bin/jq 'with_entries( select(.value | .sensitive == false ) )' > "$tmpfile"
              # Is there an update?
              if ! cmp terraform-output.json "$tmpfile" >/dev/null 2>&1
              then
                mv $tmpfile terraform-output.json
              fi
            '';
          rsync-to-deployer = pkgs.writeScriptBin "rsync-to-deployer"
            ''
              ${pkgs.rsync}/bin/rsync -e 'ssh -i ${ssh-key-path}' -azP --delete --filter=":- .gitignore" --exclude=".direnv" --exclude='.git*' . root@${deployerIP}:~/storetheindex-deployment
            '';
          ssh-to-deployer = pkgs.writeScriptBin "ssh-to-deployer"
            ''
              ${update-terraform-output}/bin/update-terraform-output
              ssh -i ${ssh-key-path} root@${deployerIP} $@
            '';
          deploy-on-deployer = pkgs.writeScriptBin "deploy-on-deployer"
            ''
              ${update-terraform-output}/bin/update-terraform-output
              ${rsync-to-deployer}/bin/rsync-to-deployer;
              ${ssh-to-deployer}/bin/ssh-to-deployer "cd storetheindex-deployment && nix develop --command deploy -s $@";
            '';
          check-fingerprints = pkgs.writeScriptBin "check-fingerprints"
            ''
              echo "Checking fingerprints..."
              ${update-terraform-output}/bin/update-terraform-output
              for IP in $(cat terraform-output.json | ${pkgs.jq}/bin/jq '.[] | .value')
              do
                echo "Trying to connect to $IP from the deployer node"
                ${ssh-to-deployer}/bin/ssh-to-deployer -t ssh $IP echo ok
              done
            '';
        in
        {
          packages.terraform = pkgs.terraform_0_14;
          packages.storetheindex = pkgs.callPackage ./storetheindex.nix { src = storetheindex-src; };
          packages.provider-load-gen = pkgs.callPackage ./provider-load-gen.nix { src = storetheindex-src; };
          defaultPackage = deploy-on-deployer;
          devShell = pkgs.mkShell {
            INDEXER_IP = indexerIP;
            INDEXER2_IP = (tf-output.indexer2IP.value or "0.0.0.0");
            GZ_INDEXER_IP = gammazeroIndexerIP;
            DEPLOYER_IP = deployerIP;
            buildInputs = [
              self.packages.${system}.terraform
              deploy-rs.defaultPackage.${system}
              update-terraform-output
              rsync-to-deployer
              ssh-to-deployer
              deploy-on-deployer
              check-fingerprints
              pkgs.jq
            ];
          };
        });
}
