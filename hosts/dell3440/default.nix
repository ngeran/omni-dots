# NixOS Configuration for dell4400
# Minimal setup for NixOS 26.05 with Hyprland and greetd

{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    # Include the results of the hardware scan
    ./hardware-configuration.nix
  ];

 # ===== BOOTLOADER =====
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
 
  # Load the modern Intel graphics module early
  boot.initrd.kernelModules = [ "i915" ];

  # ===== GRAPHICS / ACCELERATION =====
  # (hardware.graphics is the standard for NixOS 24.11+)
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver   # Modern QuickSync / VA-API acceleration for recent Intel IGPs
      vpl-gpu-rt           # Modern oneVPL runtime for Intel Iris Xe / UHD Graphics
    ];
  };
 
  # ===== NETWORKING =====
  networking.hostName = "dell3440";
  networking.networkmanager.enable = true;

  # ===== LAPTOP SPECIFIC PACKAGES & UTILS =====
  environment.systemPackages = with pkgs; [
    brightnessctl # Easy backlight control for laptop screens
    powertop      # Battery usage analyzer
  ];

  # ===== HYPRLAND COMPATIBILITY =====
  # Since you are tracking the standard NixOS channel, let NixOS manage the package 
  # versions natively instead of referencing an unimported flake input.
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # ===== SYSTEM VERSION =====
  # Match the core architecture version
  system.stateVersion = "26.05";
}
