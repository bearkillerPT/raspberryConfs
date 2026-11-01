# Raspberry Pi 4B (4GB). Same boot chain as the installer stick: the Pi firmware loads
# U-Boot from the FIRMWARE partition, U-Boot boots the extlinux entry on the root partition.
# The stock sd-image-aarch64.nix also pulls in the installer's base profile, so only the
# Pi 4 parts of it are kept here.
{ config, pkgs, modulesPath, ... }:
{
  imports = [ "${modulesPath}/installer/sd-card/sd-image.nix" ];

  nixpkgs.hostPlatform = "aarch64-linux";

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
  boot.kernelParams = [ "console=tty0" ];

  fileSystems."/".options = [ "noatime" ];

  sdImage = {
    populateFirmwareCommands =
      let
        configTxt = pkgs.writeText "config.txt" ''
          [pi4]
          kernel=u-boot-rpi4.bin
          enable_gic=1
          armstub=armstub8-gic.bin
          disable_overscan=1
          arm_boost=1

          [all]
          arm_64bit=1
          # U-Boot needs the UART enabled, even if nothing is plugged into it
          enable_uart=1
          avoid_warnings=1
        '';
      in
      ''
        (cd ${pkgs.raspberrypifw}/share/raspberrypi/boot && cp fixup4*.dat start4*.elf bcm2711-rpi-4-b.dtb $NIX_BUILD_TOP/firmware/)
        cp ${configTxt} firmware/config.txt
        cp ${pkgs.ubootRaspberryPi4_64bit}/u-boot.bin firmware/u-boot-rpi4.bin
        cp ${pkgs.raspberrypi-armstubs}/armstub8-gic.bin firmware/armstub8-gic.bin
      '';
    populateRootCommands = ''
      mkdir -p ./files/boot
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
    '';
  };
}
