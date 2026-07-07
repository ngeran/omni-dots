{ config, lib, pkgs, ... }:

{
  # Bootloader setup
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Silence boot logs so they don't overlap with greetd (tuigreet) on TTY1.
  # Without this, systemd services and kernel messages print [ OK ] status
  # lines OVER the greeter while it is drawing → the classic corrupted TTY.
  # `quiet` suppresses most kernel output; show_status=auto shows systemd
  # status only on failure/slow boot (not every service start).
  boot.kernelParams = [ "quiet" "systemd.show_status=auto" "rd.systemd.show_status=auto" ];
  boot.consoleLogLevel = 3;   # 0=emerg..7=debug; 3 = only errors and above

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
