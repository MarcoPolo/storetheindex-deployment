{ pkgs, lib, src, ... }:
pkgs.buildGo117Module rec {
  inherit src;

  pname = "storetheindex";
  version = "load-testing";
  subPackages = [ "." ];
  checkPhase = "";


  vendorSha256 = "sha256-wLRA8OJnyYSW6Uaf1qhuf+g49nrYd3TzPfKeFd6dJZA=";
  # vendorSha256 = lib.fakeSha256;

  meta = with lib; {
    description = "CID indexer";
    homepage = "https://github.com/filecoin-project/storetheindex";
    license = licenses.mit;
    maintainers = with maintainers; [ "marcopolo" ];
    platforms = platforms.linux ++ platforms.darwin;
  };
}
