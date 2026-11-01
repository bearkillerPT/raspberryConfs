{
  description = "bearkillerPT's Raspberry Pi home server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Apps served by the Pi; `nix flake update <name>` picks up new commits.
    # The private repos go through the `github.com-private` alias in ~/.ssh/config.
    park2Charge = {
      url = "git+ssh://git@github.com-private/bearkillerPT/park2Charge?ref=feature/Claude_rewrite";
      flake = false;
    };
    check-facade = {
      url = "git+ssh://git@github.com-private/bearkillerPT/check-facade";
      flake = false;
    };
    repos-website = {
      url = "github:bearkillerPT/repos-website";
      flake = false;
    };
    DataMining = {
      url = "github:bearkillerPT/DataMining";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations = {
      pi = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/pi ];
      };

      installer = nixpkgs.lib.nixosSystem {
        modules = [ ./hosts/installer ];
      };
    };

    packages.x86_64-linux = {
      # nix build .#pi-image → the full SD card image, written to the card during the cutover
      pi-image = self.nixosConfigurations.pi.config.system.build.sdImage;
      # nix build .#installer → result/sd-image/*.img.zst, written to a USB stick
      installer = self.nixosConfigurations.installer.config.system.build.sdImage;
    };

    # nix run .#deploy → builds on this machine and switches the Pi to the working tree's config
    apps.x86_64-linux.deploy =
      let
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
      in
      {
        type = "app";
        program = toString (pkgs.writeShellScript "deploy" ''
          exec ${pkgs.nixos-rebuild-ng}/bin/nixos-rebuild switch --flake .#pi \
            --target-host pi@192.168.1.141 --sudo --use-substitutes "$@"
        '');
      };

    # nix build .#checks.x86_64-linux.pi → boots the Pi's services in a VM and checks every site
    checks.x86_64-linux.pi = import ./tests/pi.nix {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      inherit inputs;
    };
  };
}
