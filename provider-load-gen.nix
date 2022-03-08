{ pkgs, lib, src, ... }:
let
in
pkgs.buildGo117Module rec {
  inherit src;
  pname = "provider-load-gen";
  version = "load-testing";

  vendorSha256 = "sha256-L37TYLxsvWlddHm9tWkk80wduoBWr1wql8XIvaNozBQ=";
  # vendorSha256 = lib.fakeSha256;

  modRoot = "load-testing";

  meta = with lib;
    {
      description = "CID Provider load generator";
      homepage = "https://github.com/filecoin-project/storetheindex";
      license = licenses.mit;
      maintainers = with maintainers; [ "marcopolo" ];
      platforms = platforms.linux ++ platforms.darwin;
    };
}
