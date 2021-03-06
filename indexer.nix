{ config, pkgs, modulesPath, ... }:
{
  imports = [ "${modulesPath}/virtualisation/amazon-image.nix" ];
  ec2.hvm = true;

  networking.hostName = "indexer";
  networking.firewall.enable = false;

  # Enable Flakes
  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  security.pam.loginLimits = [{
    domain = "*";
    type = "soft";
    item = "nofile";
    value = "65536";
  }];


  environment.systemPackages = with pkgs; [ vim tmux htop go_1_17 git ];

  users.users.root.openssh.authorizedKeys.keys = import ./ssh-authorized-keys;

  environment.etc = {
    provider-load-testing-configs.source = ./load-testing-tools/provider-load-generator/example-configs;
  };



  fileSystems."/data" = {
    # Amazon EC2 NVMe Instance Storage
    device = "/dev/nvme1n1";
    fsType = "ext4";
    autoFormat = true;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?
}
