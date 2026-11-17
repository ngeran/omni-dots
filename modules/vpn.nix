# WireGuard + Tailscale foundation for the velocity bar's nikos.wireguard
# plugin (ported from Omarchy's ngeran.wireguard).
#
# What this gives the desktop:
#   - tailscaled running as a proper NixOS service (client mode), with the
#     `tailscale` CLI usable UNPRIVILEGED by nikos via --operator — the bar
#     plugin never needs root for status/up/down/exit-node.
#   - NetworkManager told to leave tailscale0 alone: without `unmanaged`,
#     NM fights tailscaled over the interface (spurious "unmanaged device"
#     churn in nmcli output the plugin parses).
#
# WireGuard itself needs NO daemon: tunnels are plain NM connections the
# plugin drives with `nmcli` (already on the bar's PATH via runtimeInputs).
{ config, lib, ... }:

let
  cfg = config.services.velocityVpn;
in
{
  options.services.velocityVpn = {
    enable = lib.mkEnableOption "WireGuard (via NetworkManager) + Tailscale for the velocity bar";
    operator = lib.mkOption {
      type = lib.types.str;
      default = "nikos";
      description = "Unprivileged user allowed to operate tailscale without root.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      # Let the node's own firewall accept inbound tailscale traffic (peer
      # connections, SSH over tailnet) — not a VPN kill switch.
      openFirewall = true;
      # Client only: this machine routes THROUGH the tailnet, never as a
      # subnet router/exit node for others.
      useRoutingFeatures = "client";
      # `tailscale set`-style flags appended to `tailscale up`; --operator
      # grants socket access to the user so the plugin runs it directly.
      extraSetFlags = [ "--operator=${cfg.operator}" ];
    };

    networking.networkmanager.unmanaged = [
      # tailscaled owns this interface end-to-end
      "interface-name:tailscale0"
    ];
  };
}
