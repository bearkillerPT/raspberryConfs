# PlugHere (bearkillerPT/park2Charge, branch feature/Claude_rewrite): the website, the API
# and its Postgres database, the MQTT broker the chargers talk to, and the always-on emulators.
{ config, inputs, pkgs, ... }:
let
  src = inputs.park2Charge;

  website = pkgs.buildNpmPackage {
    pname = "plughere-website";
    version = src.shortRev;
    src = "${src}/plug-here-website";
    npmDepsHash = "sha256-5aBcjRH+6eCyEAaBKdT8HHl8NEdrDYONt8Z91ZH7FNU=";
    installPhase = "cp -r build $out";
  };

  # Runs its TypeScript directly (node --experimental-strip-types), so there's no build step
  api = pkgs.buildNpmPackage {
    pname = "plughere-api";
    version = src.shortRev;
    src = "${src}/api";
    nodejs = pkgs.nodejs_22;
    npmDepsHash = "sha256-EJDJ8yR8SFq3yZcr4nIP79eR8CIvM3+kETS27OgiHGM=";
    dontNpmBuild = true;
    installPhase = "cp -r . $out";
  };

  emulatorPython = pkgs.python3.withPackages (ps: [ ps.paho-mqtt ]);

  emulator = script: {
    description = "PlugHere emulator (${script})";
    wantedBy = [ "multi-user.target" ];
    after = [ "mosquitto.service" ];
    environment = {
      MQTT_BROKER = "127.0.0.1";
      MQTT_PORT = "1883";
      MQTT_USERNAME = "park2ChargeDemo";
      CONDO_ID = "1";
      STATION_IDS = "1,2";
      STATE_DIR = "/var/lib/plughere-emulation";
      PYTHONUNBUFFERED = "1";
    };
    serviceConfig = {
      ExecStart = "${emulatorPython}/bin/python ${src}/emulation-scripts/${script}";
      EnvironmentFile = config.sops.templates."plughere-emulation.env".path;
      StateDirectory = "plughere-emulation";
      User = "plughere";
      Restart = "always";
    };
  };

  apiVhost = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:3014";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_read_timeout 1h;
        proxy_send_timeout 1h;
      '';
    };
  };

  mqttUsers.park2ChargeDemo = {
    passwordFile = config.sops.secrets."plughere/mqtt-password".path;
    acl = [ "readwrite #" ];
  };
in
{
  users.users.plughere = {
    isSystemUser = true;
    group = "plughere";
  };
  users.groups.plughere = { };

  # The plugHere database and plugHereAPI role come from the old Pi's pg_dumpall
  services.postgresql.enable = true;

  services.mosquitto = {
    enable = true;
    listeners = [
      # The chargers (ESP32) and the emulators
      {
        port = 1883;
        users = mqttUsers;
      }
      # The API, and wss://mosquitto.plughere.app through nginx
      {
        port = 8081;
        settings.protocol = "websockets";
        users = mqttUsers;
      }
    ];
  };
  networking.firewall.allowedTCPPorts = [ 1883 8081 ];

  systemd.services = {
    plughere-api = {
      description = "PlugHere API";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "postgresql.service" "mosquitto.service" ];
      wants = [ "network-online.target" ];
      environment = {
        APP_PORT = "3014";
        DB_HOST = "127.0.0.1";
        DB_PORT = "5432";
        DB_USER = "plugHereAPI";
        DB_NAME = "plugHere";
        MQTT_BROKER_URL = "127.0.0.1";
        MQTT_BROKER_PORT = "8081";
        MQTT_BROKER_USERNAME = "park2ChargeDemo";
        LOG_DIR = "/var/log/plughere-api";
      };
      serviceConfig = {
        ExecStart = "${pkgs.nodejs_22}/bin/node --experimental-strip-types --trace-warnings ${api}/index.ts";
        # Uploads are saved to ./Storage/uploads
        WorkingDirectory = "/var/lib/plughere-api";
        StateDirectory = [ "plughere-api" "plughere-api/Storage" "plughere-api/Storage/uploads" ];
        LogsDirectory = "plughere-api";
        EnvironmentFile = config.sops.templates."plughere-api.env".path;
        User = "plughere";
        Restart = "always";
      };
    };

    plughere-emulation-stations = emulator "emulateStations.py";
    plughere-emulation-meter = emulator "emulateMeter.py";
  };

  sops.secrets."plughere/db-password" = { };
  sops.secrets."plughere/jwt-secret" = { };
  sops.secrets."plughere/mqtt-password" = { };
  sops.templates."plughere-api.env".content = ''
    DB_PASSWORD=${config.sops.placeholder."plughere/db-password"}
    SECRET=${config.sops.placeholder."plughere/jwt-secret"}
    MQTT_BROKER_PASSWORD=${config.sops.placeholder."plughere/mqtt-password"}
  '';
  sops.templates."plughere-emulation.env".content = ''
    MQTT_PASSWORD=${config.sops.placeholder."plughere/mqtt-password"}
  '';

  services.nginx.virtualHosts = {
    "plughere.app" = {
      serverAliases = [ "www.plughere.app" ];
      enableACME = true;
      forceSSL = true;
      root = website;
      locations."/".tryFiles = "$uri $uri/ /index.html";
    };
    "api.plughere.app" = apiVhost;
    # Older name of the API, still used by the mobile app
    "plughereapi.bearkillerpt.xyz" = apiVhost;
    "mosquitto.plughere.app" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8081";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_read_timeout 1h;
          proxy_send_timeout 1h;
        '';
      };
    };
  };
}
