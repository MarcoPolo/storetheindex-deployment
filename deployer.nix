{ config, pkgs, modulesPath, ... }:
{
  imports = [ "${modulesPath}/virtualisation/amazon-image.nix" ];
  ec2.hvm = true;

  networking.hostName = "deployer";
  networking.firewall.enable = false;

  # Enable Flakes
  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  environment.systemPackages = with pkgs; [ vim tmux htop ];

  users.users.root.openssh.authorizedKeys.keys = import ./ssh-authorized-keys;

  services.nginx =
    {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
    };

  environment.etc = {
    "grafana/dashboards".source = ./grafana/dashboards;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?
}
