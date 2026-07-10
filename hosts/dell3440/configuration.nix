# NixOS Configuration for dell4400
# Minimal setup for NixOS 26.05 with Hyprland and greetd

{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    # Include the results of the hardware scan
    ./hardware-configuration.nix
    ../system/bluetooth.nix
    ../system/audio.nix
  ];

  # ===== BOOTLOADER =====
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
 
    # Load the i915 kernel module early for your Haswell iGPU
  boot.initrd.kernelModules = [ "i915" ];

  # Enable OpenGL (hardware.graphics replaces hardware.opengl in NixOS 24.11+)
  hardware.graphics = {
    enable = true;
    
    # Add older Intel drivers for Haswell / HD 4400
    extraPackages = with pkgs; [
      intel-media-driver  # Fallback/Newer (iHD)
      intel-vaapi-driver  # Primary driver for HD 4400 (i965)
      libvdpau-va-gl
    ];
  };
 
  # ===== NETWORKING =====
  networking.hostName = "dell4400";
  networking.networkmanager.enable = true;

  # ===== LOCALE & TIME =====
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # ===== USER ACCOUNT =====
  users.users.nikos = {
    isNormalUser = true;
    description = "nikos";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      tree
    ];
  };

  # ===== SYSTEM PACKAGES =====
  environment.systemPackages = with pkgs; [
    vim
    curl
    wget
    git
    alacritty
  ];

  # ===== FONTS =====
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  # ===== HYPRLAND CONFIGURATION =====
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    # set the flake packages
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    # Set the portal package
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  # ===== NIX SETTINGS =====
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # ===== SERVICES =====
  services.openssh.enable = true;
  services.gvfs.enable = true;  # For file manager

  # ===== SYSTEM VERSION =====
  system.stateVersion = "26.05";
}
