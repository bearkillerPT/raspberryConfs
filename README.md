# raspberryConfs

Everything that runs on the Raspberry Pi 4 home server (`192.168.1.141`), as a NixOS flake.
If it's not in here, it's not on the Pi. The configs from before NixOS are under the `legacy` git tag.

## Layout

| Path | What |
|---|---|
| `flake.nix` | Inputs (nixpkgs 26.05, sops-nix, the app repos) and outputs |
| `hosts/pi/` | The server: `hardware.nix` (boot, SD image), `network.nix` (static IP), `configuration.nix` (users, SSH, nix, secrets, list of services) |
| `hosts/installer/` | The headless USB-stick installer, used to image or reinstall the SD card |
| `services/` | One file per service: its build, systemd units, nginx site and secrets |
| `sites/archive/` | Frozen builds of old sites whose toolchains no longer build |
| `secrets/` | sops-encrypted secrets (this repo is public) |
| `keys/` | Public keys: the machines that can SSH in (morpho-laptop, lenovo-laptop, windows-desktop) and the Pi's host key |
| `tests/` | VM test that boots `configuration.nix` and checks every site, with dummy secrets |

## Sites and services

| Name | Service file |
|---|---|
| bearkillerpt.xyz | `portfolio.nix` (built from `repos-website`) |
| plughere.app, api.plughere.app, plughereapi.bearkillerpt.xyz, mosquitto.plughere.app, MQTT on 1883/8081 | `plughere.nix` (built from `park2Charge`, branch `feature/Claude_rewrite`) |
| nextcloud.bearkillerpt.xyz | `nextcloud.nix` |
| gotify.bearkillerpt.xyz | `gotify.nix` |
| price-tracker.bearkillerpt.xyz | `price-tracker.nix` (built from `price-tracker`) |
| ha.bearkillerpt.xyz, and http://192.168.1.141:8123 on the LAN | `home-assistant.nix` (Home Assistant; a new kind of device may need its integration added there) |
| edapi.bearkillerpt.xyz | `edapi.nix` (from `DataMining`) |
| heaboo, iv, ed, bdl .bearkillerpt.xyz | `legacy-sites.nix` |
| check-facade (every 5 min), pccomponentes (hourly) | `check-facade.nix`, `pccomponentes/` |
| Namecheap dynamic DNS | `ddns.nix` |

Router forwards: 80, 443, 22, 1883, 8081 → the Pi; 8080 → the OpenHAB box (check-facade and Home Assistant read it).

## Everyday use

The Pi builds itself. This repo is cloned at `~/raspberryConfs` on the Pi:

```bash
cd ~/raspberryConfs
git pull                                 # changes pushed from elsewhere
nix flake update park2Charge             # pick up new commits of an app
sudo nixos-rebuild switch --flake .#pi   # build and switch
```

From another machine with Nix and this repo, `nix run .#deploy` does the same over SSH (the Pi still
does the building), and `nix build .#checks.x86_64-linux.pi -L` runs the VM test (x86_64 only).

A switch that breaks the Pi can be undone with `sudo nixos-rebuild switch --rollback`, or by picking
the previous generation in the boot menu.

The private repos (park2Charge, check-facade) are fetched through the `github.com-private` SSH alias.
On the Pi it's set up in `configuration.nix` with `~/.ssh/id_github_private`; anywhere else, define the
same alias in `~/.ssh/config`.

### Secrets

`sops secrets/pi.yaml` edits them. It needs an age key that `.sops.yaml` lists, like Gil's
`~/.config/sops/age/keys.txt`. **Keep a copy of that key somewhere safe** (a password manager): without
it, nobody can change `secrets/`, and reinstalling the Pi means recreating every secret.

`pi` has a password only for the console (keyboard and screen). To change it, run this where the age
key is, then commit, push and switch:

```bash
nix shell nixpkgs#sops nixpkgs#mkpasswd -c sh -c \
  'sops set secrets/pi.yaml "[\"pi\"][\"password-hash\"]" "\"$(mkpasswd -m yescrypt)\""'
```

## Installing or reinstalling the SD card

The Pi's bootloader tries USB before the SD card (`BOOT_ORDER=0xf14`), so the installer stick
boots the Pi with the SD card unmounted.

1. `nix build .#pi-image` builds the full SD image (on an x86_64 machine this needs aarch64
   emulation, `boot.binfmt.emulatedSystems` or qemu-user's binfmt).
2. Plug the installer stick into the Pi and reboot. It comes up as `root@192.168.1.141`
   (if it was built from `.#installer`).
3. Write the image to the card:
   `zstd -dc result/sd-image/*.img.zst | ssh root@192.168.1.141 'dd of=/dev/mmcblk0 bs=4M conv=fsync'`
4. Put the Pi's SSH host key on the card, so it can decrypt its secrets. Mount the card by device
   name: the stick's root is also labelled `NIXOS_SD`.
   ```bash
   ssh root@192.168.1.141 'partprobe /dev/mmcblk0 && mount /dev/mmcblk0p2 /mnt && mkdir -p /mnt/etc/ssh'
   sops --decrypt secrets/pi_ssh_host_ed25519_key \
     | ssh root@192.168.1.141 'install -m 600 /dev/stdin /mnt/etc/ssh/ssh_host_ed25519_key'
   scp keys/pi_ssh_host_ed25519_key.pub root@192.168.1.141:/mnt/etc/ssh/ssh_host_ed25519_key.pub
   ssh root@192.168.1.141 'umount /mnt && poweroff'
   ```
5. Unplug the stick, power-cycle the Pi. The root partition grows to fill the card on first boot.
6. Restore data (databases, Nextcloud files, Gotify, uploads) from the latest backup.
7. So the Pi can build itself again: `ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_github_private` on the
   Pi, add the `.pub` to GitHub, and clone this repo to `~/raspberryConfs`.

Never leave another bootable USB drive plugged into the Pi: it would boot instead of the SD card.
