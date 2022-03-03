{ pkgs, lib, repoHash, ... }:
let
  repo = pkgs.fetchFromGitHub {
    owner = "filecoin-project";
    repo = "storetheindex";
    rev = "marco/load-testing";
    sha256 = repoHash;
  };
in
pkgs.buildGo117Module rec {
  pname = "provider-load-gen";
  version = "load-testing";

  src = "${repo}";
  vendorSha256 = "sha256-wWbFQilGGwwmC7Xklyls15++0nHj2dESX6BAvngazME=";
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
