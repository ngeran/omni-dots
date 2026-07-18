{ config, pkgs, ... }:

{
  # ============================================================================
  # THUNAR FILE MANAGER CONFIGURATION
  # ============================================================================

  programs.thunar = {
    enable = true;
    plugins = with pkgs.xfce; [
      thunar-archive-plugin  # Adds "Create Archive" and "Extract Here" to right-click menu
      thunar-volman          # Auto-management of removable drives (USB sticks, CDs)
    ];
  };

  # ============================================================================
  # SYSTEM SERVICES (The "Engine" under the hood)
  # ============================================================================

  services = {
    gvfs.enable = true;      # Required for Trash bin, network mounts, and mounting USB drives
    udisks2.enable = true;   # Required for physical disk management and partitioning
    tumbler.enable = true;   # The background daemon that generates file thumbnails
  };

  # Essential for Thunar to remember your settings (View preferences, side-pane width, etc.)
  programs.xfconf.enable = true;

  # ============================================================================
  # PACKAGES (Backends and UI Tools)
  # ============================================================================

  environment.systemPackages = with pkgs; [
    # --- GUI Frontends ---
    xarchiver               # The lightweight window that Thunar uses to show archive contents

    # --- Archiving Backends (Engines) ---
    zip                     # Tool for creating .zip files
    unzip                   # Tool for extracting .zip files
    pkgs."7zip"             # Modern, secure replacement for p7zip. Handles .7z and more.
    unrar                   # Essential for extracting .rar files (common in downloads)
    zstd                    # Very fast modern compression used by many Linux distros
    xz                      # Standard high-compression format for Linux (.tar.xz)
    libarchive              # Provides 'bsdtar', a universal tool for many archive types

    # --- Thumbnailer Backends (Enrich the file manager) ---
    ffmpegthumbnailer       # Generates video thumbnails (shows a frame of the movie)
    poppler                 # Generates PDF document thumbnails
    libgsf                  # Generates thumbnails for ODF/Office documents
    webp-pixbuf-loader      # Allows Thunar to show thumbnails for .webp images
  ];

  # ============================================================================
  # NIXOS SYSTEM POLISH
  # ============================================================================

  # This is a critical NixOS "hack":
  # It tells the system to link thumbnailer configuration files into a place 
  # where the 'tumbler' daemon can actually see them. Without this, you 
  # might install 'ffmpegthumbnailer' but still see no video icons.
  environment.pathsToLink = [ "/share/thumbnailers" ];
}
