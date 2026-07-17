# =========================================================================
# Creative apps — DaVinci Resolve + Blender  (home / user layer)
# =========================================================================
# These are USER GUI apps → home.packages (Home Manager), NOT hosts/desktop
# (that layer is for hardware/system only — the NVIDIA driver lives there in
# modules/nvidiagpu-compute.nix). The GPU acceleration these apps use (CUDA)
# comes from that driver, so NO app-side env vars are needed on a single-NVIDIA
# machine — which is why the old davinci.nix / blender.nix global env vars were
# dropped: they were redundant, and QT_QPA_PLATFORM=xcb set globally broke
# native Wayland for EVERY Qt app on the desktop.
#
# Notes:
#   • davinci-resolve is unfree (allowed via core/default.nix → allowUnfree).
#     It bundles its own CUDA libs → GPU acceleration works automatically once
#     the NVIDIA driver is installed.
#   • If DaVinci ever misbehaves on Wayland, set QT_QPA_PLATFORM=xcb for IT
#     ONLY (a per-app wrapper / desktop entry), never as a session variable.
#   • Plain `blender` has a GPU-accelerated viewport (OpenGL, via the driver).
#     For Cycles CUDA/OptiX *rendering*, swap to:
#         (blender.override { cudaSupport = true; })
#     (heavy build, pulls unfree CUDA — only if you need GPU Cycles).
# =========================================================================
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    davinci-resolve   # non-linear video editor (CUDA-accelerated via the NVIDIA driver)
    blender           # 3D suite — GPU viewport; Cycles CUDA needs the override above
  ];
}
