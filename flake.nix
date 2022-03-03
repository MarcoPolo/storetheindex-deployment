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
          hostname = "34.222.188.35";
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
            ];
          };
        deployer = nixpkgs.lib.nixosSystem
          {
            system = "x86_64-linux";
            modules = [
              ./deployer.nix
              ./metrics.nix
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
          tf-output = builtins.fromJSON (builtins.readFile ./terraform-output.json);
          deployerIP = tf-output.deployerIP.value;
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
              ${rsync-to-deployer}/bin/rsync-to-deployer;
              ${ssh-to-deployer}/bin/ssh-to-deployer "cd storetheindex-deployment && nix develop --command deploy -s .#deployer";
            '';
        in
        {
          packages.storetheindex = pkgs.callPackage ./storetheindex.nix { };
          packages.provider-load-gen = pkgs.callPackage ./provider-load-gen.nix { };
          defaultPackage = self.packages.${system}.storetheindex;
          devShell = pkgs.mkShell {
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
