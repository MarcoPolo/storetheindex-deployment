{ pkgs, lib, ... }:
pkgs.buildGo117Module rec {
  pname = "provider-load-gen";
  version = "0.0.1";

  src = ./.;

  vendorSha256 = (import ./vendorSha.nix).sha256;

  meta = with lib; {
    description = "CID Provider load generator";
    homepage = "https://github.com/filecoin-project/storetheindex";
    license = licenses.mit;
    maintainers = [ "marcopolo" ];
    platforms = platforms.linux ++ platforms.darwin;
  };
}
