# Everything that runs on the Pi, minus the board and network specifics.
# The VM test (tests/pi.nix) boots this file too.
{ inputs, pkgs, ... }:
{
  imports = [
    inputs.sops-nix.nixosModules.sops
    ../../services/nginx.nix
    ../../services/portfolio.nix
    ../../services/legacy-sites.nix
    ../../services/edapi.nix
    ../../services/plughere.nix
    ../../services/nextcloud.nix
    ../../services/gotify.nix
    ../../services/check-facade.nix
    ../../services/pccomponentes
    ../../services/ddns.nix
  ];

  system.stateVersion = "26.05";

  time.timeZone = "Europe/Lisbon";
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.pi = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keyFiles = [ ../../keys/laptop.pub ];
  };
  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  services.fail2ban.enable = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    # Deploys copy store paths over SSH as pi
    trusted-users = [ "pi" ];
    auto-optimise-store = true;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Go easy on the SD card
  zramSwap.enable = true;
  boot.tmp.useTmpfs = true;
  services.journald.extraConfig = "SystemMaxUse=200M";

  sops.defaultSopsFile = ../../secrets/pi.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  environment.systemPackages = with pkgs; [
    fastfetch
    git
    htop
  ];
}
