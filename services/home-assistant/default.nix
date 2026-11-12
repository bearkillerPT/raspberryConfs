# Home Assistant at ha.bearkillerpt.xyz, and on the LAN at http://192.168.1.141:8123.
#
# Integrations are added in the UI. This file only decides which ones have their Python
# dependencies installed (extraComponents): a new kind of device that fails to set up needs its
# integration (the last part of its home-assistant.io/integrations/<name> URL) added below and a
# deploy. The UI's own state (.storage, the database, backups) lives in /var/lib/hass; Nix only
# writes configuration.yaml.
{ config, pkgs, ... }:
let
  port = 8123;
  lan = "192.168.1.0/24";

  # openHAB (the heating controller), read-only: every item becomes a sensor. Added in the UI
  # (Settings → Devices & services → Add integration → openHAB); source in ./openhab.
  openhab = pkgs.buildHomeAssistantComponent {
    owner = "bearkillerPT";
    domain = "openhab";
    version = "1.0.0";
    src = ./openhab;
  };

  # Automations, scenes and scripts made in the UI are saved here
  uiFiles = [ "automations.yaml" "scenes.yaml" "scripts.yaml" ];
in
{
  services.home-assistant = {
    enable = true;
    extraComponents = [
      # Set up by onboarding (and the module's own defaults)
      "default_config"
      "met"
      "esphome"
      "rpi_power"
      "google_translate"
      "radio_browser"
      "shopping_list"
      "analytics"
      # Faster websocket compression
      "isal"

      # Media
      "cast"
      "sonos"
      "samsungtv"
      "webostv"
      "androidtv"
      "androidtv_remote"
      "dlna_dmr"
      "dlna_dms"
      "upnp"

      # Wi-Fi plugs and bulbs
      "tuya"
      "tplink"
      "shelly"
      "xiaomi_miio"
      "xiaomi_ble"
      "yeelight"
      "hue"
      "wled"

      # Zigbee, through a USB coordinator (the module gives HA the serial ports)
      "zha"

      # Found on the LAN, or tried in the UI
      "roborock"
      "huawei_lte"
      "co2signal"
    ];
    customComponents = [ openhab ];

    config = {
      default_config = { };

      homeassistant = {
        # Name, location and elevation are set during onboarding: this repo is public
        unit_system = "metric";
        currency = "EUR";
        country = "PT";
        internal_url = "http://192.168.1.141:${toString port}";
        external_url = "https://ha.bearkillerpt.xyz";
      };

      http = {
        server_port = port;
        # Behind nginx: log and ban the client's address, not nginx's
        use_x_forwarded_for = true;
        trusted_proxies = [ "127.0.0.1" "::1" ];
        ip_ban_enabled = true;
        login_attempts_threshold = 5;
      };

      "automation ui" = "!include automations.yaml";
      "scene ui" = "!include scenes.yaml";
      "script ui" = "!include scripts.yaml";
    };
  };

  systemd.tmpfiles.rules = map (
    file: "f ${config.services.home-assistant.configDir}/${file} 0644 hass hass - []"
  ) uiFiles;

  # The Pi 4's onboard radio, for Bluetooth LE sensors
  hardware.bluetooth.enable = true;

  services.nginx.virtualHosts."ha.bearkillerpt.xyz" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      # The UI and the phone app keep a WebSocket open
      proxyWebsockets = true;
      extraConfig = ''
        proxy_read_timeout 1h;
        proxy_send_timeout 1h;
      '';
    };
  };

  # Only from the LAN (the router forwards none of these, but the Pi also has a public IPv6):
  # the web UI on 8123, Sonos' event callbacks, and UDP for device discovery. Discovery
  # protocols (mDNS, SSDP, TP-Link, Shelly…) answer multicast or broadcast queries from their
  # own ports, which the firewall's connection tracking can't match to the query.
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -s ${lan} -p tcp --dport ${toString port} -j nixos-fw-accept
    iptables -A nixos-fw -s ${lan} -p tcp --dport 1400 -j nixos-fw-accept
    iptables -A nixos-fw -s ${lan} -p udp -j nixos-fw-accept
  '';
}
