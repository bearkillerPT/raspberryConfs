# Every 5 minutes: read the facade temperatures from OpenHAB (behind the router's port 8080)
# and push a Gotify alert when something looks wrong. bearkillerPT/check-facade.
{ config, inputs, pkgs, ... }:
{
  systemd.services.check-facade = {
    description = "Check the facade temperatures on OpenHAB";
    startAt = "*:0/5";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python ${inputs.check-facade}/check_temps.py";
      EnvironmentFile = config.sops.templates."gotify-scripts.env".path;
      StateDirectory = "check-facade";
      DynamicUser = true;
    };
  };
}
