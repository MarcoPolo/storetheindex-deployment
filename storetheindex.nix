{ pkgs, lib, ... }:
pkgs.buildGo117Module rec {
  pname = "storetheindex";
  version = "load-testing";
  subPackages = [ "." ];
  checkPhase = "";

  src = pkgs.fetchFromGitHub {
    owner = "filecoin-project";
    repo = "storetheindex";
    rev = "marco/load-testing";
    sha256 = "sha256-sAk7sy4jw+NQWGbFaZ62gvAupms6G2XruyzqzwYwoow=";
  };

  vendorSha256 = "sha256-7ZAAJiADH4K8B7PEUWUvxlnRTVIB4psKAOT+pMnufCA=";

  meta = with lib; {
    description = "CID indexer";
    homepage = "https://github.com/filecoin-project/storetheindex";
    license = licenses.mit;
    maintainers = with maintainers; [ "marcopolo" ];
    platforms = platforms.linux ++ platforms.darwin;
  };
}
