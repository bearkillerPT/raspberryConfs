# bearkillerpt.xyz: static build of bearkillerPT/repos-website (Create React App, yarn).
{ inputs, pkgs, ... }:
let
  site = pkgs.stdenv.mkDerivation {
    pname = "portfolio";
    version = inputs.repos-website.shortRev;
    src = inputs.repos-website;
    yarnOfflineCache = pkgs.fetchYarnDeps {
      yarnLock = "${inputs.repos-website}/yarn.lock";
      hash = "sha256-gzvNKA2NAV1WbqVcSwQT4oZadnCNJVqkIAIVwbJvyYA=";
    };
    nativeBuildInputs = with pkgs; [
      yarnConfigHook
      yarnBuildHook
      nodejs
    ];
    installPhase = "cp -r build $out";
  };
in
{
  services.nginx.virtualHosts."bearkillerpt.xyz" = {
    serverAliases = [ "www.bearkillerpt.xyz" ];
    enableACME = true;
    forceSSL = true;
    root = site;
  };
}
