{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/audio.nix
    ../../modules/bluetooth.nix
    ../../modules/nvidiagpu-compute.nix  # NVIDIA RTX 5080 + CUDA (was amdgpu-compute.nix)
    ../../modules/ollama.nix             # local LLM (CUDA) — Qwen2.5-Coder-32B tuned for 16 GB VRAM
    ../../modules/open-webui.nix         # chat UI + docs RAG front-end (native service, localhost:8080)
    ../../modules/ghost-drive.nix        # suppress MSI monitor's broken 22 KB virtual USB storage (kills sda I/O spam)
    ../../modules/apps/virtualization.nix
    ../../modules/greetd.nix
    ../../modules/apps/file-manager.nix
    ../../modules/stylix.nix
    ../../modules/matugen.nix        # runtime wallpaper→palette generator (hybrid with stylix)
    ../../modules/fonts.nix
    ../../modules/apps/desktop-apps.nix
    ../../modules/apps/dev-tools.nix
    ../../modules/apps/sniffnet.nix    # network traffic monitor (cap-wrapped, runs unprivileged)
    ../../modules/apps/hashcat.nix     # GPU password cracker (CUDA backend wrapped for the RTX 5080)
    ../../modules/apps/netwatch.nix    # network diagnostics TUI (eBPF/cap-wrapped, runs unprivileged)
    ../../modules/pwnagotchi.nix       # USB OTG gadget ethernet + avahi/mDNS host-side for the pwni
    ../../modules/serial-access.nix    # uaccess ACL on ttyACM/ttyUSB — browser firmware flashers (Web Serial)
    ../../modules/ssh.nix
    ../../labs/k8s-telemetry/nix/k3s.nix  # opt-in: single-node k3s cluster (telemetry lab)
    ../../labs/k8s-registry.nix           # opt-in: local registry for fast dev->k3s deploys (nutils etc.)
  ];

  networking.hostName = "nixos-btw";

  # =========================================================================
  # Boot speed — stop waiting for the network at boot
  # =========================================================================
  # `systemd-analyze blame` showed NetworkManager-wait-online.service eating
  # 14.5 s of the ~18 s userspace boot: it blocks boot completion until EVERY
  # interface (Wi-Fi + Ethernet) reports "online". Nothing on this machine
  # needs the network before the desktop appears — the registry container
  # only LISTENS on :5000, and k3s/ollama are on-demand. This removes the
  # service from network-online.target's wants, so boot no longer waits on
  # link state. The network still comes up in the background exactly as
  # before; NM itself is untouched.
  systemd.services.NetworkManager-wait-online.wantedBy = lib.mkForce [ ];
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
    device = "UUID=e3fbe232-e469-489f-a4fb-72369b790171";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };

  fileSystems."/mnt/WD_BLACK-500GB" = {
    device = "UUID=f5f52fbd-5857-45a5-8cee-5776b5b39894";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
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

  # =========================================================================
  # Screen Locking (hyprlock) — MUST be enabled via this module, not a package
  # =========================================================================
  # hyprlock authenticates your password through Linux-PAM. Installing the
  # `hyprlock` PACKAGE alone does not create /etc/pam.d/hyprlock, so PAM falls
  # back to /etc/pam.d/other, which on NixOS DENIES everything — the screen
  # locks and NO password can ever unlock it (lockout until you switch to a
  # TTY and kill the process). Enabling the NixOS module installs hyprlock AND
  # wires the PAM service. This is why `hyprlock` was removed from
  # modules/apps/desktop-apps.nix — one source of truth (the module installs
  # the package itself).
  programs.hyprlock.enable = true;

  # =========================================================================
  # Secrets — gnome-keyring, unlocked automatically at login
  # =========================================================================
  # Without a keyring daemon, Chromium silently falls back to storing saved
  # passwords in PLAINTEXT inside ~/.config/chromium. Enabling gnome-keyring
  # gives apps (Chromium via the gnome-libsecret flag in home/chromium.nix,
  # seahorse, network secrets) an encrypted store on disk, held in memory
  # after unlock.
  #
  # The PAM piece comes for free: NixOS's greetd module defaults
  # security.pam.services.greetd.enableGnomeKeyring to this same switch, so
  # the keyring unlocks with your login password at the tuigreet prompt —
  # no extra prompt after login.
  services.gnome.gnome-keyring.enable = true;

  # NOTE: user groups live in ONE place — core/default.nix (users.users.nikos).
  # A second extraGroups list here used to re-add networkmanager/render/video;
  # NixOS merges lists, so it was harmless but misleading (two places to check
  # when auditing permissions). Removed — edit groups in core only.

  # Enable unpatched dynamic binaries to run seamlessly
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    # Add any common missing shared libraries here if needed later
    stdenv.cc.cc
    zlib
  ];

 }
