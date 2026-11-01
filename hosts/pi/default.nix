# The Raspberry Pi 4 home server. configuration.nix holds everything that also runs
# in the VM test; this file adds what only makes sense on the real board.
{
  imports = [
    ./hardware.nix
    ./network.nix
    ./configuration.nix
  ];
}
