{ config, pkgs, modulesPath ... }:
{
  imports = [ "${toString modulesPath}/virtualisation/amazon-image.nix" ];

  networking.hostName = "indexer";

  # Enable Flakes
  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
      builders-use-substitutes = true
    '';
  };
}
