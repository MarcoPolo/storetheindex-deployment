{
  description = "A very basic flake";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/release-21.11";
  inputs.deploy-rs = {
    url = "github:serokell/deploy-rs";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, deploy-rs, flake-utils }:
    {
      deploy.nodes = {
        indexer = {
          # TODO would be ideal if this would just work, but we don't commit the tfstate file
          # hostname = (builtins.fromJSON (builtins.readFile ./terraform.tfstate)).outputs.ip.value;
          hostname = "34.222.188.35";
          profiles.system = {
            user = "root";
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.indexer;
          };
        };
        deployer = {
          hostname = "35.84.143.136";
          profiles.system = {
            user = "root";
            sshUser = "root";
            # sshOpts = [ "-i" "/Users/marco/.ssh/marco-storetheindex-deployment" ];
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.indexer;
          };
        };
      };
      nixosConfigurations = {
        indexer = nixpkgs.lib.nixosSystem
          {
            system = "x86_64-linux";
            modules = [ ./indexer.nix ];
          };
        deployer = nixpkgs.lib.nixosSystem
          {
            system = "x86_64-linux";
            modules = [ ./deployer.nix ];
          };
      };
    } //
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs { system = system; };
        in
        {
          packages.hello = pkgs.hello;
          packages.storetheindex = pkgs.callPackage ./storetheindex.nix { go = pkgs.go_1_17; };
          defaultPackage = self.packages.${system}.hello;
          devShell = pkgs.mkShell {
            buildInputs = [
              pkgs.terraform_0_14
              deploy-rs.defaultPackage.${system}
            ];
          };
        });
}
