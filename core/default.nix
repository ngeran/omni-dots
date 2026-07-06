{ config, lib, pkgs, ... }:

{
  # Bootloader setup
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Core Localization
  time.timeZone = "America/New_York";

  # Global Networking Core
  networking.networkmanager.enable = true;

  # =========================================================================
  # Nix Package Manager Settings
  # =========================================================================
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      # From old config: Automatically links identical files in the store to save space
      auto-optimise-store = true; 
    };
    
    # From old config: Automates system cleaning
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  # From old config: Required for proprietary drivers and many dev tools
  nixpkgs.config.allowUnfree = true;
  # --- POWER MANAGEMENT ---
  powerManagement.powertop.enable = true;

  # =========================================================================
  # Global User Definition
  # =========================================================================
  users.users.nikos = {
    isNormalUser = true;
    # Combined groups from current and old config
    extraGroups = [ 
      "wheel"           # Sudo
      "networkmanager"  # WiFi/Ethernet
      "render"          # GPU Compute
      "video"           # GPU Display
      "docker"          # If you use docker
      "libvirtd"        # If you use virtualization
    ];
    packages = with pkgs; [ tree ];
  };

  # Essential System-Wide Packages
  environment.systemPackages = with pkgs; [
    wget
    git
  ];

  # System State Version baseline
  system.stateVersion = "26.05";
}
