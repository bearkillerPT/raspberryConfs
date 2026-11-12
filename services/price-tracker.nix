# Price tracker (bearkillerPT/price-tracker): follows product prices on Amazon and other EU shops and
# posts drops to Gotify. One Node server (API + web app) on its own Postgres database; it starts a
# headless Chromium for sign-ins, price picking and shops that need a browser.
#
# First time, and whenever the app password is forgotten (trackers are kept):
#   sudo -u price-tracker price-tracker reset-password
{ config, inputs, lib, pkgs, ... }:
let
  src = inputs.price-tracker;
  nodejs = pkgs.nodejs_24;
  pnpm = pkgs.pnpm_11;
  port = 4380;
  databaseUrl = "postgres://price-tracker@/price-tracker?host=/run/postgresql";

  # The server and the CLI are esbuild bundles that only need Node; the web app is static files
  package = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "price-tracker";
    # A local checkout given with --override-input has no revision
    version = src.shortRev or "local";
    inherit src;

    nativeBuildInputs = [ nodejs pnpm pkgs.pnpmConfigHook pkgs.makeWrapper ];
    pnpmDeps = pkgs.fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      inherit pnpm;
      fetcherVersion = 5;
      hash = "sha256-ZzKdjrl80hJeRwLAPNmWvkQwuR0ioHQ+Gq0wapB7haY=";
    };

    buildPhase = ''
      runHook preBuild
      pnpm build
      runHook postBuild
    '';

    # dist/ finds the web app in ../web and its migrations in dist/drizzle
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/price-tracker $out/bin
      cp -r apps/api/dist $out/lib/price-tracker/dist
      cp -r apps/web/dist $out/lib/price-tracker/web
      makeWrapper ${nodejs}/bin/node $out/bin/price-tracker-server \
        --add-flags --enable-source-maps --add-flags $out/lib/price-tracker/dist/main.js
      makeWrapper ${nodejs}/bin/node $out/bin/price-tracker \
        --add-flags $out/lib/price-tracker/dist/cli.js \
        --set-default DATABASE_URL '${databaseUrl}'
      runHook postInstall
    '';
  });

  # The Chromium that playwright-core (pinned to nixpkgs' playwright-driver version) looks for
  browsers = pkgs.playwright-driver.browsers-chromium;
  # Sign-in pages and price picking are looked at through the streamed browser, so give it fonts
  fonts = pkgs.makeFontsConf {
    fontDirectories = [ pkgs.dejavu_fonts pkgs.liberation_ttf pkgs.noto-fonts-color-emoji ];
  };
in
{
  users.users.price-tracker = {
    isSystemUser = true;
    group = "price-tracker";
    home = "/var/lib/price-tracker";
  };
  users.groups.price-tracker = { };

  services.postgresql = {
    enable = true;
    ensureDatabases = [ "price-tracker" ];
    ensureUsers = [
      {
        name = "price-tracker";
        ensureDBOwnership = true;
      }
    ];
  };

  systemd.services.price-tracker = {
    description = "Price tracker";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "postgresql.target" ];
    wants = [ "network-online.target" ];
    requires = [ "postgresql.target" ];
    environment = {
      PORT = toString port;
      DATABASE_URL = databaseUrl;
      PLAYWRIGHT_BROWSERS_PATH = "${browsers}";
      FONTCONFIG_FILE = "${fonts}";
      HOME = "/var/lib/price-tracker";
      XDG_CACHE_HOME = "/var/cache/price-tracker";
    };
    serviceConfig = {
      ExecStart = "${package}/bin/price-tracker-server";
      # SESSION_KEY (encrypts store sign-ins) and the Gotify token
      EnvironmentFile = config.sops.templates."price-tracker.env".path;
      User = "price-tracker";
      Group = "price-tracker";
      StateDirectory = "price-tracker";
      CacheDirectory = "price-tracker";
      WorkingDirectory = "/var/lib/price-tracker";
      Restart = "always";
      RestartSec = 10;
      # Chromium is started on demand and closed when idle; keep a runaway one from taking the Pi down
      MemoryMax = "1536M";
      PrivateTmp = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };
  };

  environment.systemPackages = [ package ];

  # Generate with: openssl rand -base64 32. Changing it drops the saved store sign-ins.
  sops.secrets."price-tracker/session-key" = { };
  sops.templates."price-tracker.env".content = ''
    SESSION_KEY=${config.sops.placeholder."price-tracker/session-key"}
    GOTIFY_URL=http://127.0.0.1:8082
    GOTIFY_TOKEN=${config.sops.placeholder."gotify/scripts-token"}
  '';

  services.nginx.virtualHosts."price-tracker.bearkillerpt.xyz" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      # The live browser view streams over a WebSocket
      proxyWebsockets = true;
      extraConfig = ''
        proxy_read_timeout 1h;
        proxy_send_timeout 1h;
      '';
    };
  };
}
