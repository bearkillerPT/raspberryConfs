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
  imports = [
    ./facade-alerts.nix
    ./solar.nix
  ];

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

      # Matter, through matter-server below (the SONOFF AirGuard CO2 is Matter over Wi-Fi)
      "matter"

      # Found on the LAN, or tried in the UI
      "roborock"
      "co2signal"
    ];
    customComponents = [
      openhab
      # The solar inverter, over Modbus TCP
      (pkgs.callPackage ./huawei-solar.nix { })
    ];

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

  # HA's Matter integration connects to it at ws://localhost:5580/ws (the firewall keeps 5580
  # closed). Matter over Wi-Fi needs no Thread border router; Thread devices would.
  services.matter-server.enable = true;
  # Matter devices report back over UDP flows the server opened, sometimes minutes apart. The
  # kernel forgets an idle UDP flow after 120 s, and the firewall then drops the next report;
  # matter.js recommends an hour. The module is loaded early so the setting applies at boot.
  boot.kernelModules = [ "nf_conntrack" ];
  boot.kernel.sysctl."net.netfilter.nf_conntrack_udp_timeout_stream" = 3600;

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
  # Over IPv6 the LAN is the link-local range, which can't come from the internet: Matter
  # finds devices with IPv6 mDNS.
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -s ${lan} -p tcp --dport ${toString port} -j nixos-fw-accept
    iptables -A nixos-fw -s ${lan} -p tcp --dport 1400 -j nixos-fw-accept
    iptables -A nixos-fw -s ${lan} -p udp -j nixos-fw-accept
    ip6tables -A nixos-fw -s fe80::/10 -p udp -j nixos-fw-accept
  '';
}
