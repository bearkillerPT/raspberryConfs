# Gotify push notifications. The phone app connects to gotify.bearkillerpt.xyz; the scripts
# (check-facade, pccomponentes) post to it locally on port 8082.
{ config, ... }:
{
  services.gotify = {
    enable = true;
    environment = {
      GOTIFY_SERVER_LISTENADDR = "127.0.0.1";
      GOTIFY_SERVER_PORT = 8082;
    };
    # Only used while the database is empty: the migrated gotify.db brings its own users
    environmentFiles = [ config.sops.templates."gotify.env".path ];
  };

  sops.secrets."gotify/default-user-password" = { };
  sops.templates."gotify.env".content = ''
    GOTIFY_DEFAULTUSER_PASS=${config.sops.placeholder."gotify/default-user-password"}
  '';

  # Application token the scripts post with
  sops.secrets."gotify/scripts-token" = { };
  sops.templates."gotify-scripts.env".content = ''
    GOTIFY_URL=http://127.0.0.1:8082
    GOTIFY_TOKEN=${config.sops.placeholder."gotify/scripts-token"}
  '';

  services.nginx.virtualHosts."gotify.bearkillerpt.xyz" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8082";
      proxyWebsockets = true;
    };
  };
}
