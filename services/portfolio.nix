# bearkillerpt.xyz: static build of bearkillerPT/repos-website (Create React App, yarn).
{ inputs, ... }:
let
  # The output is plain files, so build it natively on the deploy machine (x86_64)
  # instead of under ARM emulation
  buildPkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;

  site = buildPkgs.stdenv.mkDerivation {
    pname = "portfolio";
    version = inputs.repos-website.shortRev;
    src = inputs.repos-website;
    yarnOfflineCache = buildPkgs.fetchYarnDeps {
      yarnLock = "${inputs.repos-website}/yarn.lock";
      hash = "sha256-gzvNKA2NAV1WbqVcSwQT4oZadnCNJVqkIAIVwbJvyYA=";
    };
    nativeBuildInputs = with buildPkgs; [
      yarnConfigHook
      yarnBuildHook
      nodejs
    ];
    installPhase = "cp -r build $out";
  };
in
{
  services.nginx.virtualHosts."bearkillerpt.xyz" = {
    enableACME = true;
    forceSSL = true;
    root = site;
  };
}
