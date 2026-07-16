# =========================================================================
# NVIDIA GPU + CUDA compute  (replaces modules/amdgpu-compute.nix)
# =========================================================================
# Migrated AMD RX 7600 XT (ROCm) → NVIDIA RTX 5080 Blackwell (CUDA).
# Mirrors amdgpu-compute.nix's 4-part structure: kernel/driver → Ollama → tools.
#
# The 5080 (Blackwell GB203) needs driver >= 570; nixpkgs stable ships 595.x —
# well above the floor — so we use the STABLE driver (no beta needed).
#
# Hyprland-on-NVIDIA requirements baked in:
#   • hardware.nvidia.modesetting.enable = true     — REQUIRED for Wayland
#   • boot.kernelParams "nvidia_drm.modeset=1"      — REQUIRED for Wayland
#   • open kernel modules                            — recommended for Blackwell (≥570)
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

  # NixOS gate: `videoDrivers = [ "nvidia" ]` is the TRIGGER that adds the NVIDIA
  # kernel module to the tree + wires libglvnd/OpenGL. Without it the initrd build
  # dies with "modprobe: FATAL: Module nvidia not found". It does NOT start X —
  # xserver stays disabled; we're pure-Wayland via greetd. This just registers
  # the driver so `boot.initrd.kernelModules` (below/above) can resolve `nvidia`.
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Match the driver to the running kernel (boot.kernelPackages = linuxPackages_latest).
    package = config.boot.kernelPackages.nvidiaPackages.stable;  # 595.x → supports the 5080
    modesetting.enable = true;     # REQUIRED for Wayland compositors
    open = true;                   # open GPU kernel modules — recommended for Blackwell (≥570).
                                   # If anything glitches (rare), set open = false for proprietary.
    powerManagement.enable = true; # runtime D3 sleep (idle power savings; optional)
    nvidiaSettings = true;         # `nvidia-settings` GUI
    # forceFullCompositionPipeline = true;  # uncomment if you see screen tearing
  };

  # =========================================================================
  # 3. Ollama — CUDA instead of ROCm (was pkgs.ollama-rocm)
  # =========================================================================
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    # rocmOverrideGfx / HSA_OVERRIDE_GFX_VERSION were AMD-only — removed.
  };

  # =========================================================================
  # 4. System tools — NVIDIA/CUDA introspection (replaces rocm-smi / rocminfo)
  # =========================================================================
  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia   # GPU monitor (was rocm-smi)
    clinfo                 # OpenCL info (works via the nvidia OpenCL ICD)
    pciutils               # lspci — confirm the 5080 is seated
  ];
}
