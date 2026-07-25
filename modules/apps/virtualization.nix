{ config, lib, pkgs, ... }:

{
  # =========================================================================
  # 1. System-Level Virtualization & Container Daemons
  # =========================================================================
  
  # QEMU/KVM Configuration
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
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
  networking.bridges = { };
  
  environment.systemPackages = with pkgs; [
    virt-viewer
    dnsmasq
    vde2
    bridge-utils
    netcat-openbsd 
    ebtables
    nftables
    libguestfs
  ];

  # =========================================================================
  # 3. GUI & Hook Enablement
  # =========================================================================
  programs.virt-manager.enable = true;

  # =========================================================================
  # 4. User Access Permissions
  # =========================================================================
  users.users.nikos.extraGroups = [ "libvirtd" "kvm" "docker" ];
}
