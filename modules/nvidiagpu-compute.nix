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
  # 2b. Disable dynamic (RTD3) GPU power management — fix for Xid 154 freezes
  # =========================================================================
  # On 2026-07-25 the machine hard-froze (no input, hard reset required). The
  # frozen boot's kernel log showed an NVIDIA GSP firmware heartbeat timeout
  # fired from the modesetting idle timer → Xid 154 → full-GPU-reset-required
  # → frozen display:
  #     NVRM: GPU0 _kgspIsHeartbeatTimedOut: Heartbeat timed out ... timeout 5200
  #     NVRM: GPU0 _kgspRpcRecvPoll: LibOS heartbeat timed out
  #     NVRM: Xid (PCI:0000:01:00): 154, GPU recovery action ... 0x1 (GPU Reset Required)
  # The hang originated in IdleTimerProc — the GPU entered a low-power (RTD3)
  # state and the GSP failed to wake cleanly. Disabling dynamic power management
  # is the #1 mitigation for this class of Blackwell-open-module GSP hang. On an
  # always-on-AC desktop the only cost is a little idle GPU wattage.
  #
  # powerManagement.enable above (VRAM save/restore on suspend) is unrelated and
  # stays on — that governs sleep/resume, not idle RTD3.
  #
  # Verify after rebuild:  cat /sys/module/nvidia/parameters/NVreg_DynamicPowerManagement
  # (expect 0x00 / "disabled"). NOTE (driver 595): that sysfs path no longer
  # exists — the authoritative read is now:  grep DynamicPowerManagement
  # /proc/driver/nvidia/params  (confirmed "0" on 2026-08-17).
  #
  # RECURRENCE 2026-08-17 (~19:30): hard freeze DESPITE the RTD3 disable —
  # black screen, GPU fans racing to 100%, power-button recovery. Zero kernel
  # or journal evidence: journald's 5-min sync window lost the final lines
  # (fixed same day — SyncIntervalSec=15s in core/default.nix) and pstore was
  # empty (no kernel panic; the GPU locked the whole host first). Symptom set
  # matches the documented GB203 open-module GSP-firmware-crash class
  # (open-gpu-kernel-modules issues #1151 / #1111), reported by others across
  # drivers 580/595/610 AND Windows on some cards. Escalation path if it
  # recurs: try a different driver branch (nvidiaPackages.beta / production),
  # and if it persists across drivers, treat the CARD as the suspect
  # (warranty/RMA), not the driver.
  boot.extraModprobeConfig = ''
    options nvidia "NVreg_DynamicPowerManagement=0x00"
  '';

  # =========================================================================
  # 3. Ollama — CUDA instead of ROCm
  # =========================================================================
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
  };

  # On-demand: do NOT auto-start ollama at boot (mirrors the k3s pattern in
  # labs/k8s-telemetry/nix/k3s.nix). The CUDA daemon inits the GPU on startup —
  # wasted boot time + idle GPU memory on a daily driver when you're not doing
  # local AI. Start it when you sit down to use it:
  #     sudo systemctl start ollama      # models load only on first request
  #     sudo systemctl stop ollama       # frees the VRAM
  systemd.services.ollama.wantedBy = lib.mkForce [ ];

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
