# NixOS Configuration for Dell Latitude 3440
{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ===== BOOTLOADER =====
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
 
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
  # This initializes the theme engine so home-manager can read the colors
  stylix = {
    enable = true;
    image = pkgs.fetchurl {
      url = "https://www.pixelstalk.net/wp-content/uploads/2016/06/Solid-Black-Wallpaper-HD.jpg";
      sha256 = "sha256-47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU="; 
    };
    base16Scheme = "${pkgs.base16-schemes}/share/themes/tomorrow-night.yaml";
  };

  # ===== LAPTOP SPECIFIC PACKAGES & UTILS =====
  environment.systemPackages = with pkgs; [
    brightnessctl 
    powertop      
  ];

  # ===== HYPRLAND CONFIGURATION =====
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  system.stateVersion = "26.05";
}
