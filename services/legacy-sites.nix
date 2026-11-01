# Old uni and side projects, frozen as their last build (sites/archive): their toolchains
# (Create React App 4, Expo 41) no longer build, and nobody is changing them anymore.
let
  site = name: {
    enableACME = true;
    forceSSL = true;
    root = ../sites/archive + "/${name}";
    locations."/".tryFiles = "$uri $uri/ /index.html";
  };
in
{
  services.nginx.virtualHosts = {
    "heaboo.bearkillerpt.xyz" = site "heaboo";
    "iv.bearkillerpt.xyz" = site "iv";
    # Its API is in edapi.nix
    "ed.bearkillerpt.xyz" = site "ed";
    # Chess, from Board-Description-Language_and_ABDL
    "bdl.bearkillerpt.xyz" = site "bdl";
  };
}
