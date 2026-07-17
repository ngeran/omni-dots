# blender.nix
# Standalone configuration for Blender with NVIDIA CUDA support
# This file should be imported into your home.nix or configuration.nix
{ config, pkgs, ... }:

{
  # ==========================================================================
  # 1. INSTALL BLENDER WITH CUDA
  # ==========================================================================
  # NOTE: Installing Blender with CUDA at the user level (home-manager)
  # may not work reliably. It's recommended to install at the system level
  # in configuration.nix or flake.nix.
  #
  # If you want to try user-level installation, uncomment:
  # home.packages = with pkgs; [
  #   (blender.override { cudaSupport = true; })
  # ];

  # ==========================================================================
  # 2. ENVIRONMENT VARIABLES FOR BLENDER
  # ==========================================================================
  home.sessionVariables = {
    # ----------------------------------------------------------------------
    # CUDA CONFIGURATION
    # ----------------------------------------------------------------------
    # Explicitly tell Blender which NVIDIA GPU to use
    # Use "0" for the first GPU, "1" for second, etc.
    # CUDA_VISIBLE_DEVICES = "0";

    # Force Blender to use the system's CUDA toolkit path
    # This helps Blender find CUDA libraries
    # CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";

    # ----------------------------------------------------------------------
    # BLENDER PERFORMANCE OPTIMIZATION
    # ----------------------------------------------------------------------
    # Disable GPU memory oversubscription (can cause crashes)
    # BLENDER_CUDA_MEMORY_LIMIT = "0.8";  # Use 80% of GPU memory

    # Enable experimental OptiX denoising (uses RT cores)
    # BLENDER_OPTIX_DENOISER = "1";

    # ----------------------------------------------------------------------
    # NVIDIA OPENGL SETTINGS (Affects Blender's viewport)
    # ----------------------------------------------------------------------
    # Use NVIDIA's OpenGL implementation for better performance
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # Reduce input lag and improve responsiveness
    __GL_SYNC_TO_VBLANK = "0";  # Disable vertical sync (can cause tearing)

    # Improve performance in viewport
    __GL_THREADED_OPTIMIZATIONS = "1";

    # ----------------------------------------------------------------------
    # WAYLAND VS X11
    # ----------------------------------------------------------------------
    # If using Wayland, Blender may have issues. Force X11 backend:
    # GDK_BACKEND = "x11";

    # Or if using Wayland and want to try:
    # BLENDER_WAYLAND_ENABLE = "1";
  };

  # ==========================================================================
  # 3. SHELL ALIASES (Optional)
  # ==========================================================================
  programs.bash = {
    enable = true;
    shellAliases = {
      # Launch Blender with CUDA and additional options
      blender-cuda = "blender --enable-cuda";

      # Launch Blender with factory settings (for troubleshooting)
      blender-factory = "blender --factory-startup";

      # Launch Blender with debug logging (useful for troubleshooting)
      blender-debug = "blender --debug --log-level 2";
    };
  };

  # ==========================================================================
  # 4. DESKTOP INTEGRATION
  # ==========================================================================
  # Create custom desktop entry with environment variables baked in
  # This is optional but can be useful for launching from the application menu
  # xdg.desktopEntries.blender = {
  #   name = "Blender (CUDA)";
  #   exec = "env CUDA_VISIBLE_DEVICES=0 blender";
  #   icon = "blender";
  #   categories = [ "Graphics" "3DGraphics" ];
  #   comment = "3D modeling with CUDA support";
  # };
}
