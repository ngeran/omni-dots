{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/audio.nix
    ../../modules/bluetooth.nix
    ../../modules/amdgpu-compute.nix
    ../../modules/apps/virtualization.nix
    ../../modules/greetd.nix
    ../../modules/apps/file-manager.nix
    ../../modules/stylix.nix
    ../../modules/fonts.nix
    ../../modules/apps/desktop-apps.nix
    ../../modules/apps/dev-tools.nix
  ];

  networking.hostName = "nixos-btw";
  ===== LASTEST STABLE KERNEL =====
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.kernelModules = [ "kvm-amd" ];

  # =========================================================================
  # Storage Configurations
  # =========================================================================
  fileSystems."/mnt/DATA-2T" = {
    device = "UUID=1b079941-401f-430f-97e7-8eacd6b25e82";
    fsType = "ext4";
    options = [ "defaults" ];
  };

  fileSystems."/mnt/SSD-250" = {
    device = "UUID=C8057DD5A2F97C72";
    fsType = "ntfs";
    options = [ "defaults" "uid=1000" "gid=100" ];
  };

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
