{
  networking.hostName = "pi";
  networking.wireless.enable = false;

  # Static, so the router's port forwards always land here
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.networks."10-ethernet" = {
    matchConfig.Type = "ether";
    address = [ "192.168.1.141/24" ];
    gateway = [ "192.168.1.254" ];
    dns = [ "192.168.1.254" "1.1.1.1" ];
  };
}
