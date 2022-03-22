{ pkgs, lib, ... }:
pkgs.buildGo117Module rec {
  pname = "provider-load-gen";
  version = "0.0.1";

  src = ./.;

  vendorSha256 = "sha256-dUYWfXCpjgpuo3jIkjUeSazF1Q3a0ow+rrhHrVcODzY=";

  modRoot = "load-testing";

  meta = with lib; {
    description = "CID Provider load generator";
    homepage = "https://github.com/filecoin-project/storetheindex";
    license = licenses.mit;
    maintainers = [ "marcopolo" ];
    platforms = platforms.linux ++ platforms.darwin;
  };
}
