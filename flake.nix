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
        sidecar = {
          # Todo make this a runtime attribute
          hostname = "35.88.223.159";
          profiles.system = {
            user = "root";
            sshUser = "root";
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
      };
    } //
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs { system = system; };
        in
        {
          packages.hello = pkgs.hello;
          defaultPackage = self.packages.${system}.hello;
          devShell = pkgs.mkShell {
            buildInputs = [
              pkgs.terraform_0_14
              deploy-rs.defaultPackage.${system}
            ];
          };
        });
}
