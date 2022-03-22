{ pkgs, lib, ... }:
pkgs.buildGo117Module rec {
  pname = "provider-load-gen";
  version = "0.0.1";

  src = ./.;

  vendorSha256 = "sha256-dUYWfXCpjgpuo3jIkjUeSazF1Q3a0ow+rrhHrVcODzY=";
  # vendorSha256 = lib.fakeSha256;
  # vendorSha256 = (import ./vendorSha.nix).sha256;

  modRoot = "load-testing";

  meta = with lib; {
    description = "CID Provider load generator";
    homepage = "https://github.com/filecoin-project/storetheindex";
    license = licenses.mit;
    maintainers = [ "marcopolo" ];
    platforms = platforms.linux ++ platforms.darwin;
  };
  postInstall = ''
    mkdir -p $out/etc/load-testing-configs
    cp -r ${./load-testing-configs}/* $out/etc/load-testing-configs/
  '';
}
