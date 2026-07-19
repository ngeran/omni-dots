# =========================================================================
# NVIDIA GPU + CUDA compute  (replaces modules/amdgpu-compute.nix)
# =========================================================================
# Migrated AMD RX 7600 XT (ROCm) → NVIDIA RTX 5080 Blackwell (CUDA).
# Mirrors the previous module's 4-part structure: kernel/driver → Ollama → tools.
#
# The 5080 (Blackwell GB203) needs driver >= 570 with OPEN kernel modules —
# proprietary modules have NO Blackwell support at all (not just "not recommended").
# nixpkgs' nvidiaPackages.stable tracks NVIDIA's production branch, which has
# been comfortably above the 570 floor for a while — no beta driver needed.
# Don't hardcode the exact version here; verify what's actually resolved with:
#   nix eval --raw .#nixosConfigurations.<host>.config.hardware.nvidia.package.version
#
# Hyprland-on-NVIDIA requirements baked in:
#   • hardware.nvidia.modesetting.enable = true     — REQUIRED for Wayland
#   • boot.kernelParams "nvidia_drm.modeset=1"      — REQUIRED for Wayland
#   • open kernel modules                            — MANDATORY on Blackwell (≥570)
#
# NOTE: requires nixpkgs.config.allowUnfree = true (nvidia driver, nvidia-settings,
# and ollama-cuda are all unfree) — set this in flake.nix / configuration.nix if
# it isn't already set globally.
#
# GPU driver swaps load at BOOT — after `omni-apply`, REBOOT:
#     omni-apply && systemctl reboot
# (If the graphical session is unusable, run omni-apply from a TTY: Ctrl+Alt+F2.)
# =========================================================================
{ config, lib, pkgs, ... }:

{
  # =========================================================================
  # 1. Kernel modules + params — NVIDIA on Wayland REQUIRES nvidia_drm.modeset=1
  # =========================================================================
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  boot.kernelParams = [
    "nvidia_drm.modeset=1"   # REQUIRED for Hyprland/Wayland
    "nvidia_drm.fbdev=1"     # working framebuffer console on the TTY
  ];

  # =========================================================================
  # 2. Graphics pipeline + NVIDIA driver
  # =========================================================================
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      nvidia-vaapi-driver   # VA-API → NVDEC bridge (browsers, mpv, ffmpeg decode)
    ];
  };

  # NVIDIA has no native VA-API on Linux — apps need to be told to use the
  # bridge above, and to prefer the faster direct-rendering backend over EGL.
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
  };

  # NixOS gate: `videoDrivers = [ "nvidia" ]` is the TRIGGER that adds the NVIDIA
  # kernel module to the tree + wires libglvnd/OpenGL. Without it the initrd build
  # dies with "modprobe: FATAL: Module nvidia not found". It does NOT start X —
  # xserver stays disabled; we're pure-Wayland via greetd. This just registers
  # the driver so `boot.initrd.kernelModules` (below/above) can resolve `nvidia`.
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Match the driver to the running kernel (boot.kernelPackages = linuxPackages_latest).
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    modesetting.enable = true;     # REQUIRED for Wayland compositors
    open = true;                   # MANDATORY on Blackwell — proprietary modules do not
                                    # support GB20x at all. Do NOT flip this to false to
                                    # troubleshoot; it will break GPU init entirely.
    powerManagement.enable = true; # saves/restores VRAM state across suspend/resume
    nvidiaSettings = true;         # `nvidia-settings` GUI
  };

  # =========================================================================
  # 3. Ollama — CUDA instead of ROCm
  # =========================================================================
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
  };

  # =========================================================================
  # 4. System tools — NVIDIA/CUDA introspection
  # =========================================================================
  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia   # GPU monitor
    clinfo                 # OpenCL info (works via the nvidia OpenCL ICD)
    pciutils               # lspci — confirm the 5080 is seated
    ocl-icd                # ICD loader
  ];
}
