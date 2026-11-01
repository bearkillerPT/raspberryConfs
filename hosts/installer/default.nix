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
  users.users.root.openssh.authorizedKeys.keyFiles = [
    ../../keys/morpho-laptop.pub
    ../../keys/lenovo-laptop.pub
    ../../keys/windows-desktop.pub
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [ zstd pv parted rsync ];
}
