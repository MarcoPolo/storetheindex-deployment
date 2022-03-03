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
      tf-output = builtins.fromJSON (builtins.readFile ./terraform-output.json);
      deployerIP = tf-output.deployerIP.value;
      indexerIP = tf-output.indexerIP.value;
      gammazeroIndexerIP = tf-output.gammazeroIndexerIP.value;
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
        gammazeroIndexer = {
          hostname = gammazeroIndexerIP;
          profiles.system = {
            user = "root";
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.indexer;
          };
        };
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
                environment.systemPackages = with self.packages."x86_64-linux"; [ storetheindex provider-load-gen ];
              }
            ];
          };
        deployer = nixpkgs.lib.nixosSystem
          {
            system = "x86_64-linux";
            modules = [
              ./deployer.nix
              (import ./metrics.nix indexerIP)
              {
                environment.systemPackages = with self.packages."x86_64-linux"; [ storetheindex provider-load-gen ];
              }
            ];
          };
      };
    } //
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs { system = system; };
          ssh-key-path = "~/.ssh/marco-storetheindex-deployment";
          rsync-to-deployer = pkgs.writeScriptBin "rsync-to-deployer"
            ''
              ${pkgs.rsync}/bin/rsync -e 'ssh -i ${ssh-key-path}' -azP --delete --filter=":- .gitignore" --exclude=".direnv" --exclude='.git*' . root@${deployerIP}:~/storetheindex-deployment
            '';
          ssh-to-deployer = pkgs.writeScriptBin "ssh-to-deployer"
            ''
              ssh -i ${ssh-key-path} root@${deployerIP} $@
            '';
          deploy-on-deployer = pkgs.writeScriptBin "deploy-on-deployer"
            ''
              terraform output -json > terraform-output.json
              ${rsync-to-deployer}/bin/rsync-to-deployer;
              ${ssh-to-deployer}/bin/ssh-to-deployer "cd storetheindex-deployment && nix develop --command deploy -s $@";
            '';
        in
        {
          packages.storetheindex = pkgs.callPackage ./storetheindex.nix { src = storetheindex-src; };
          packages.provider-load-gen = pkgs.callPackage ./provider-load-gen.nix { src = storetheindex-src; };
          defaultPackage = self.packages.${system}.storetheindex;
          devShell = pkgs.mkShell {
            INDEXER_IP = indexerIP;
            GZ_INDEXER_IP = gammazeroIndexerIP;
            DEPLOYER_IP = deployerIP;
            buildInputs = [
              pkgs.terraform_0_14
              deploy-rs.defaultPackage.${system}
              rsync-to-deployer
              ssh-to-deployer
              deploy-on-deployer
            ];
          };
        });
}
