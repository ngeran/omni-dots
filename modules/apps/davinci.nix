# davinci.nix
# Standalone configuration for DaVinci Resolve (can be imported into home.nix)
{ pkgs, ... }:

{
  # ==========================================================================
  # 1. INSTALL DAVINCI RESOLVE
  # ==========================================================================
  home.packages = with pkgs; [
    # Use the free version
    # If you have a paid license key, change to 'davinci-resolve-studio'
    davinci-resolve
  ];

  # ==========================================================================
  # 2. DAVINCI RESOLVE ENVIRONMENT VARIABLES (NVIDIA OPTIMIZED)
  # ==========================================================================
  home.sessionVariables = {
    # ----------------------------------------------------------------------
    # UI SCALING
    # ----------------------------------------------------------------------
    # Auto-scale UI for high-DPI monitors (4K, 5K, etc.)
    # Set to "0" to disable, "1" to enable
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";

    # Force Qt to use XCB backend (better compatibility than Wayland)
    # Some users report issues with Wayland and DaVinci Resolve
    QT_QPA_PLATFORM = "xcb";

    # ----------------------------------------------------------------------
    # NVIDIA GPU OPTIMIZATION
    # ----------------------------------------------------------------------
    # FOR AMD USERS (REMOVED): 
    # ROC_ENABLE_PRE_VEGA is for AMD GPUs only - NOT needed for NVIDIA
    # We've removed the AMD-specific variable

    # Use NVIDIA's proprietary OpenGL for better performance
    # This ensures DaVinci Resolve uses the correct OpenGL implementation
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # Reduce screen tearing in OpenGL applications
    __GL_YIELD = "USLEEP";

    # Force NVIDIA GPU as the primary rendering device
    # If you have multiple GPUs, set this to the correct device index
    # CUDA_VISIBLE_DEVICES = "0";  # Uncomment if needed

    # ----------------------------------------------------------------------
    # DAVINCI RESOLVE MEMORY SETTINGS
    # ----------------------------------------------------------------------
    # Increase GPU memory allocation (adjust based on your RTX 5080's VRAM)
    # RTX 5080 has 16GB of VRAM, so we can set a generous limit
    # DAVINCI_RESOLVE_GPU_MEMORY_LIMIT = "16384";  # 16GB

    # Enable GPU acceleration for video decoding/encoding
    # DAVINCI_RESOLVE_HARDWARE_DECODING = "1";

    # ----------------------------------------------------------------------
    # TROUBLESHOOTING OPTIONS
    # ----------------------------------------------------------------------
    # If DaVinci Resolve crashes on startup, try these:
    # DISABLE_GPU = "1";  # Disables GPU acceleration (fallback to CPU)
    # NV_USE_BETA_DRIVERS = "1";  # Use beta NVIDIA drivers if available
  };

  # ==========================================================================
  # 3. ADDITIONAL FONTS (Optional)
  # ==========================================================================
  # DaVinci Resolve may need specific fonts for the UI
  # You can install fonts via home.packages if needed:
  # fonts = with pkgs; [
  #   noto-fonts
  #   noto-fonts-cjk
  #   dejavu_fonts
  # ];
}
