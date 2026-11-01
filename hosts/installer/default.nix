# Headless installer that boots the Pi from a USB stick, so the SD card is free
# to be imaged and reinstalled over SSH.
{ lib, pkgs, modulesPath, ... }:
{
  imports = [ "${modulesPath}/installer/sd-card/sd-image-aarch64-installer.nix" ];

  nixpkgs.hostPlatform = "aarch64-linux";

  networking.hostName = "pi-installer";

  # Same address as the old system: it's the same machine, so they never run at once.
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.networks."10-ethernet" = {
    matchConfig.Type = "ether";
    address = [ "192.168.1.141/24" ];
    gateway = [ "192.168.1.254" ];
    dns = [ "192.168.1.254" "1.1.1.1" ];
  };

  # Fallback if the static address doesn't come up: ssh root@pi-installer.local
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  # The stock installer only starts sshd from the console, and the Pi has no screen.
  systemd.services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];
  services.openssh.settings.PasswordAuthentication = false;
  users.users.root.openssh.authorizedKeys.keys = [
    # laptop (~/.ssh/id_rsa)
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC8+t/wTP8FOB+aFHU9Wwzp8vxYaHDPBj1xL9CVemLpFLbYSB3MJbB9DsprzneYNzl2XBBDaUa3XNrmN+j5j78JPTWMI6VRGPU3qi75GGlOg4SiYg4syqJEGwWXkqV8LrTMD2FPzXruOogp9oyN4dpWGl6zW0W4ZcAojGgzZwgxTJ37713cxM++VKalDisBYQjESBYf5JPQkmh96ZoG69OK3IosZssDu+vOwMPj03hhg5IUfI95LTgD8dgA3NHXPxQG51r6+TkjFHXt6s31qEO5Qz124vXW3HQeEkOdLws2izw/yxTBZnPi5BU0iAGjebmo0WKfSZoIohg2DlNp2m20d3Eg4XBZxKdcIB6I5gJ9gLOBMDbc4pwbtb7wONRseoygMKblREGDIJdboYQbOR7rWjiDmr1AayUEeg17ZsBOJglPhhVbIJdr1ZNNko6gaNDzTFuuCqQcDd/x33OmN7Qkx3WdYdXL1Ijdlmf1Kast3RK5UyRiQFZlDUGYbqO7KqkCq2xtyKif7af0OERbxRSDDgsE9+kp5lYoPPi7oHIEalj51kzZNHt/fXH4hJDdm+gwfgMZJgypljbt0BhpvULu1v+PF9yxjQhMjTS4344ML4amm0Rbs7aBm+pcLjD1+6Tr9xhofR9LmqRmhnH8j2VD7c6ZY8JXsdK6r/kid0lGyw=="
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [ zstd pv parted rsync ];
}
