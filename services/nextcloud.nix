# nextcloud.bearkillerpt.xyz. Fresh install; the old instance's files are copied in and
# rescanned during the cutover (users bearkillerpt and gilteixeira).
{ config, pkgs, ... }:
{
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud33;
    hostName = "nextcloud.bearkillerpt.xyz";
    https = true;
    maxUploadSize = "16G";
    configureRedis = true;
    database.createLocally = true;
    config = {
      dbtype = "pgsql";
      adminuser = "bearkillerpt";
      adminpassFile = config.sops.secrets."nextcloud/admin-password".path;
    };
    settings = {
      default_phone_region = "PT";
      # Background jobs run from 02:00 UTC
      maintenance_window_start = 2;
    };
    phpOptions."opcache.interned_strings_buffer" = "16";
    # Sized for a 4GB Pi that runs everything else too
    poolSettings = {
      pm = "dynamic";
      "pm.max_children" = "8";
      "pm.start_servers" = "2";
      "pm.min_spare_servers" = "1";
      "pm.max_spare_servers" = "3";
    };
  };

  sops.secrets."nextcloud/admin-password".owner = "nextcloud";

  services.nginx.virtualHosts."nextcloud.bearkillerpt.xyz" = {
    enableACME = true;
    forceSSL = true;
  };
}
