{ config, lib, pkgs, ... }:

{
  # =========================================================================
  # Host platform
  # =========================================================================
  # Replaces the deprecated `system = "x86_64-linux"` argument to
  # nixpkgs.lib.nixosSystem (which emits the "'system' has been renamed to
  # stdenv.hostPlatform.system" evaluation warning). Both hosts (desktop +
  # dell3440) are x86_64-linux and import this module, so it's set once here.
  nixpkgs.hostPlatform = "x86_64-linux";

  # Bootloader setup
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 10;  # cap EFI entries so /boot can't fill up

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
      # Parallel builds — use all 16 threads of the 7700X (was unset → effectively 1).
      max-jobs = "auto";
      cores = 0;
      # Let nikos's user-level builds (just build, dev shells) use the trusted caches.
      trusted-users = [ "root" "nikos" ];
      # Pre-built binaries for nixvim + other nix-community packages, so omni-apply
      # doesn't compile them from source. cache.nixos.org kept as the primary.
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qfPWdQMj6QzdK7H6YhKSpexVfOlIVS+gzrfY="
      ];
    };
    
    # From old config: Automates system cleaning
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
      persistent = true;             # run missed cycles after downtime (laptop was off)
      randomizedDelaySec = "30min";  # spread the GC load off the exact weekly mark
    };
  };

  # From old config: Required for proprietary drivers and many dev tools
  nixpkgs.config.allowUnfree = true;
  # (powertop moved to hosts/dell3440 — on an always-on-AC desktop its aggressive
  #  USB/device autosuspend + CPU tweaks fight NVIDIA power management and can drop
  #  USB peripherals; the laptop keeps it for battery life.)

  # =========================================================================
  # Performance + stability (desktop, always-on-AC)
  # =========================================================================
  # TCP BBR + fq_codel — better throughput + lower latency than the defaults
  # (cubic / pfifo_fast). Helps the registry, k3s pulls, big downloads.
  boot.kernelModules = [ "tcp_bbr" "sch_fq_codel" ];
  boot.kernel.sysctl = {
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "fq_codel";
  };

  # Kill the largest process BEFORE the kernel OOM-killer freezes the whole
  # desktop (e.g. Ollama + a browser + a build maxing RAM). Better a killed tab
  # than a hard reboot.
  services.earlyoom.enable = true;

  # Compressed-RAM swap (zstd) — the PRIMARY swap, faster than disk. A safety
  # net for memory pressure; uses CPU only when actually swapping. The NixOS
  # zramSwap module gives zram a higher priority than the 4 GB disk swap
  # partition in hardware-configuration.nix (live: zram prio 5 vs disk prio -1),
  # so the disk partition is only touched as last-resort overflow once zram is
  # exhausted — not "no disk swap", but zram-first.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
  };

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
    # `tree` lives in home-manager (modules/apps/essentials.nix) — single source.
  };

  # Essential System-Wide Packages
  environment.systemPackages = with pkgs; [
    wget
    git
  ];

  # System State Version baseline
  system.stateVersion = "26.05";
}
