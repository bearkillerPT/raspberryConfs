{
  description = "bearkillerPT's Raspberry Pi home server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs, ... }: {
    nixosConfigurations.installer = nixpkgs.lib.nixosSystem {
      modules = [ ./hosts/installer ];
    };

    # nix build .#installer → result/sd-image/*.img.zst, written to a USB stick
    packages.x86_64-linux.installer = self.nixosConfigurations.installer.config.system.build.sdImage;
  };
}
