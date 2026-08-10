{ pkgs, ... }:

{
  # sniffnet — Rust GUI network-traffic monitor (1.5.0). It captures raw
  # packets via libpcap, which normally requires root. To "activate" it as a
  # normal desktop app we grant the binary the two capture-related file
  # capabilities through a setcap wrapper — the same pattern NixOS uses for
  # Wireshark's dumpcap. No setuid, no sudo: the caps live on the wrapper file.
  #
  #   cap_net_raw   — open AF_PACKET raw sockets (the actual capture). Essential.
  #   cap_net_admin — set the interface into promiscuous mode (sniffnet's
  #                   "promiscuous" checkbox). Drop this line if you want the
  #                   minimal-privilege build; raw capture still works without it.
  #
  # Why a system module, not home-manager: security.wrappers is NixOS-only.
  #
  # Launch path: the package's .desktop has `Exec=sniffnet` (a bare name), and
  # /run/wrappers/bin is ahead of /run/current-system/sw/bin on PATH, so both a
  # terminal `sniffnet` and an app-menu launch resolve to this capped wrapper —
  # no .desktop override required.

  # Pull the package in for its .desktop entry, icon, and bundled resources.
  environment.systemPackages = [ pkgs.sniffnet ];

  # Cap the executable so packet capture works unprivileged.
  security.wrappers.sniffnet = {
    source = "${pkgs.sniffnet}/bin/sniffnet";
    capabilities = "cap_net_raw,cap_net_admin+eip";
    owner = "root";
    group = "users";
    permissions = "u+rx,g+rx"; # users group can execute; 'other' cannot
  };
}
