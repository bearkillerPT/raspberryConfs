# Every hour: track the cheapest Google Pixel 10 Pro on PCComponentes, push a Gotify message
# when the price drops, plus a daily summary at 10:00.
{ config, pkgs, ... }:
let
  python = pkgs.python3.withPackages (ps: [ ps.requests ps.beautifulsoup4 ]);
in
{
  systemd.services.pccomponentes = {
    description = "Track the cheapest Pixel 10 Pro on PCComponentes";
    startAt = "hourly";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${python}/bin/python ${./pccomponentes_cheapest.py}";
      EnvironmentFile = config.sops.templates."gotify-scripts.env".path;
      StateDirectory = "pccomponentes";
      DynamicUser = true;
    };
  };
}
