{ pkgs, lib, src, ... }:
pkgs.buildGo117Module rec {
  pname = "provider-load-gen";
  version = "0.0.1";
  src = ./.;
  vendorSha256 = (import ./vendorSha.nix).sha256;

  meta = with lib; {
    description = "storetheindex read load generator";
    homepage = "https://github.com/marcopolo/storetheindex-deployment";
    license = licenses.mit;
    maintainers = [ "marcopolo" ];
    platforms = platforms.linux ++ platforms.darwin;
  };
}
