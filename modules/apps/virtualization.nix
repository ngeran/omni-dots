# =========================================================================
# VIRTUALIZATION — libvirt/KVM + Docker (VMs, virt-manager, registry host)
# =========================================================================
# On-demand philosophy mirrors the rest of the system: heavy daemons do not
# run until something needs them. Docker stays boot-started because the
# local registry container (labs/k8s-registry.nix) auto-starts on top of it.
#
# CLEANED 2026-09-15 (audit): dropped options/packages that re-stated
# defaults or were never used (runAsRoot=true default, empty networking
# bridges, vde2/bridge-utils/ebtables/nftables/libguestfs — none referenced
# by this config; libvirt manages bridges via netlink and the NixOS firewall
# goes through iptables-nft, so the raw tools were dead closure weight).
# dnsmasq STAYS: the libvirtd module's service PATH does not include it, so
# the default NAT network needs it visible in the system profile.
#
# User groups: `docker` and `libvirtd` are granted ONCE, in core/default.nix
# (the single source for users.users.nikos.extraGroups). Only `kvm` is added
# here — it is virtualization-specific and core does not carry it.
{ config, lib, pkgs, ... }:

{
  # =========================================================================
  # 1. System-Level Virtualization & Container Daemons
  # =========================================================================

  # QEMU/KVM Configuration
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      # qemu_kvm (not the default pkgs.qemu): same thing minus the
      # cross-target emulators we never use — smaller closure.
      package = pkgs.qemu_kvm;
      swtpm.enable = true;   # TPM 2.0 passthrough for Windows 11 guests
    };
  };

  # On-demand: do NOT auto-start libvirtd at boot (mirrors k3s / ollama). The
  # libvirtd + virtlogd daemons and their sockets are boot overhead for VMs you
  # only run occasionally. virt-manager still works — `libvirtd.socket` stays
  # enabled, so the FIRST API call (opening virt-manager, `virsh`) socket-
  # activates the daemon lazily. Or start it explicitly:
  #     sudo systemctl start libvirtd
  # (libvirt-guests.service, which resumes suspended VMs at boot, is a harmless
  # no-op when none were running.)
  systemd.services.libvirtd.wantedBy = lib.mkForce [ ];

  # Docker Configuration (Persistent Engine Layout)
  virtualisation.docker = {
    enable = true;

    # Modern NixOS way: Redirect engine storage to survive ephemeral reboots
    daemon.settings = {
      data-root = "/persist/var/lib/docker";
    };

    # Log clamping to prevent container storage bloat over time
    logDriver = "json-file";
    extraOptions = "--log-opt max-size=10m --log-opt max-file=3";
  };

  # =========================================================================
  # 2. Required Networking & Utility Backends
  # =========================================================================
  # Only what libvirt/virt-manager actually need at runtime (see the CLEANED
  # note in the banner for what was removed and why).
  environment.systemPackages = with pkgs; [
    virt-viewer
    dnsmasq         # default NAT network DHCP/DNS (not in libvirtd's service PATH)
    netcat-openbsd  # libvirt's remote transport probes
  ];

  # =========================================================================
  # 3. GUI & Hook Enablement
  # =========================================================================
  programs.virt-manager.enable = true;

  # =========================================================================
  # 4. User Access Permissions
  # =========================================================================
  # `kvm` only — docker/libvirtd already come from core/default.nix.
  users.users.nikos.extraGroups = [ "kvm" ];
}
