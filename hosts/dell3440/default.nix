# NixOS Configuration for Dell Latitude 3440
{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/audio.nix
    ../../modules/bluetooth.nix
    ../../modules/greetd.nix
    ../../modules/ssh.nix
    ../../modules/fonts.nix
    ../../modules/apps/desktop-apps.nix
    ../../modules/apps/desktop-apps.nix
    ../../modules/apps/file-manager.nix
    ../../modules/apps/dev-tools.nix
  ];

  # ===== BOOTLOADER =====
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ===== LASTEST STABLE KERNEL =====
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.initrd.kernelModules = [ "i915" ];

  # ===== GRAPHICS / ACCELERATION =====
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
    ];
  };
 
  # ===== NETWORKING =====
  networking.hostName = "dell3440";
  networking.networkmanager.enable = true;

  # ===== STYLIX THEME ACTIVATION =====
  stylix = {
    enable = true;
    # Generate a pure #000000 canvas locally to avoid remote 404 errors and protect OLED panels
    image = pkgs.runCommand "pure-black.png" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
      convert -size 1x1 xc:#000000 $out
    '';
    base16Scheme = "${pkgs.base16-schemes}/share/themes/tomorrow-night.yaml";
  };

  # ===== LAPTOP SPECIFIC PACKAGES & UTILS =====
  environment.systemPackages = with pkgs; [
    brightnessctl
    powertop
  ];

  # Powertop auto-tune at boot (moved here from core — only the laptop on battery
  # benefits; on the always-on-AC desktop powertop fought NVIDIA PM + dropped USB
  # peripherals, so it's desktop-off, laptop-on).
  powerManagement.powertop.enable = true;

  # ===== HYPRLAND CONFIGURATION =====
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  system.stateVersion = "26.05";
}
