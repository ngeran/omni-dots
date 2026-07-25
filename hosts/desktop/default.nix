{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/audio.nix
    ../../modules/bluetooth.nix
    ../../modules/nvidiagpu-compute.nix  # NVIDIA RTX 5080 + CUDA (was amdgpu-compute.nix)
    ../../modules/apps/virtualization.nix
    ../../modules/greetd.nix
    ../../modules/apps/file-manager.nix
    ../../modules/stylix.nix
    ../../modules/matugen.nix        # runtime wallpaper→palette generator (hybrid with stylix)
    ../../modules/fonts.nix
    ../../modules/apps/desktop-apps.nix
    ../../modules/apps/dev-tools.nix
    ../../modules/ssh.nix
    ../../labs/k8s-telemetry/nix/k3s.nix  # opt-in: single-node k3s cluster (telemetry lab)
    ../../labs/k8s-registry.nix           # opt-in: local registry for fast dev->k3s deploys (nutils etc.)
  ];

  networking.hostName = "nixos-btw";
  # ===== LASTEST STABLE KERNEL =====
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Modern AMD P-State EPP driver (Zen 4) — better frequency scaling than acpi-cpufreq.
  # Concatenated with core's + NVIDIA's kernelParams.
  boot.kernelParams = [ "amd_pstate=active" ];

  #  boot.kernelModules = [ "kvm-amd" ];

  # =========================================================================
  # Storage Configurations
  # =========================================================================
  fileSystems."/mnt/INLAND-500GB" = {
    device = "UUID=5acb5a34-9e8b-423e-946d-6d7d9e89f94c";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };

  #fileSystems."/mnt/SSD-250" = {
  #  device = "UUID=C8057DD5A2F97C72";
  #  fsType = "ntfs";
  #  options = [ "defaults" "uid=1000" "gid=100" ];
  #};

  # Native Kernel Bind Mounts for Neovim Persistence
  # Maps your volatile home space cleanly to your persistent storage block
  fileSystems."/home/nikos/.local/share/nvim" = {
    device = "/persist/home/nikos/.local/share/nvim";
    fsType = "none"; # <-- Added
    options = [ "bind" "noauto" "x-systemd.automount" ];
  };

  fileSystems."/home/nikos/.local/state/nvim" = {
    device = "/persist/home/nikos/.local/state/nvim";
    fsType = "none"; # <-- Added
    options = [ "bind" "noauto" "x-systemd.automount" ];
  };
  # fIX iSSUS aFTER CLEAN INSTALL 

  systemd.tmpfiles.rules = [
      "d /persist/home/nikos                       0755 nikos users -"
      "d /persist/home/nikos/.local                0755 nikos users -"
      "d /persist/home/nikos/.local/state          0755 nikos users -"
      "d /persist/home/nikos/.local/state/nvim     0755 nikos users -"
      "d /persist/home/nikos/.local/share          0755 nikos users -"
      "d /persist/home/nikos/.local/share/nvim     0755 nikos users -"
    ];

  # =========================================================================
  # Compositor Environment
  # =========================================================================
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Modern way to handle Portals
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [ "hyprland" "gtk" ];
  };

  # Add hardware permissions for the user
  users.users.nikos.extraGroups = [ "networkmanager" "render" "video" ];

  # Enable unpatched dynamic binaries to run seamlessly
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    # Add any common missing shared libraries here if needed later
    stdenv.cc.cc
    zlib
  ];

 }
