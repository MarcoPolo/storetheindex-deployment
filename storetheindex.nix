{ pkgs, lib, ... }:
pkgs.buildGo117Module rec {
  pname = "storetheindex";
  version = "0.3.5";

  src = pkgs.fetchFromGitHub {
    owner = "filecoin-project";
    repo = "storetheindex";
    rev = "v${version}";
    sha256 = "sha256-QbWudQzglMRqeKEBRq3rqzO8ti3H9sxuz/y7L6jQPbk=";
  };

  vendorSha256 = "sha256-+zyRlwxjAfsxZ2tTibC2KMPM5mIR6cA/N82coi+T/K8=";

  meta = with lib; {
    description = "CID indexer";
    homepage = "https://github.com/filecoin-project/storetheindex";
    license = licenses.mit;
    maintainers = with maintainers; [ "marcopolo" ];
    platforms = platforms.linux ++ platforms.darwin;
  };
}
