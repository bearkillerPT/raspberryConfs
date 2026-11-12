# Everything that runs on the Pi, minus the board and network specifics.
# The VM test (tests/pi.nix) boots this file too.
{ config, inputs, pkgs, ... }:
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
    ../../services/price-tracker.nix
    ../../services/home-assistant
    ../../services/pccomponentes
    ../../services/ddns.nix
  ];

  system.stateVersion = "26.05";

  time.timeZone = "Europe/Lisbon";
  i18n.defaultLocale = "en_US.UTF-8";

  # Users come only from this config, so the password below applies on every switch
  users.mutableUsers = false;
  users.users.pi = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    # For logging in with a keyboard and screen; SSH stays key-only
    hashedPasswordFile = config.sops.secrets."pi/password-hash".path;
    openssh.authorizedKeys.keyFiles = [
      ../../keys/morpho-laptop.pub
      ../../keys/lenovo-laptop.pub
      ../../keys/windows-desktop.pub
    ];
  };
  sops.secrets."pi/password-hash".neededForUsers = true;
  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  services.fail2ban = {
    enable = true;
    # Never ban the home network
    ignoreIP = [ "192.168.1.0/24" ];
  };

  # The private app repo (park2Charge) is fetched through this alias, so
  # `sudo nixos-rebuild` on the Pi can build itself. The key was generated on the Pi and
  # added to GitHub by hand.
  programs.ssh.extraConfig = ''
    Host github.com-private
      HostName github.com
      User git
      IdentityFile /home/pi/.ssh/id_github_private
      IdentitiesOnly yes
  '';
  programs.ssh.knownHosts."github.com".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

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
