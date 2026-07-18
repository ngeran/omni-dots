{ config, pkgs, ... }:

{
  # 1. Thunar & Plugins
  programs.thunar = {
    enable = true;
    plugins = with pkgs.xfce; [
      thunar-archive-plugin
      thunar-volman
    ];
  };

  # 2. Support Services
  services.gvfs.enable = true;    # Mounting, trash, remote filesystems
  services.udisks2.enable = true; # Storage management
  services.tumbler.enable = true; # Thumbnail daemon
  programs.xfconf.enable = true;  # Essential for saving Thunar preferences

  # 3. Packages: Backends & Thumbnailers
  environment.systemPackages = with pkgs; [
    # GUI Frontends
    xarchiver

    # Archive Backends (The "engines" that do the work)
    zip
    unzip
    7zip        # Modern replacement for p7zip
    unrar       # For .rar files
    zstd        # Fast modern compression
    xz          # Standard high-compression
    libarchive  # Provides 'bsdtar' for broader format support

    # Thumbnailer Engines (Enrich the file manager experience)
    ffmpegthumbnailer # Video thumbnails
    poppler           # PDF thumbnails
    libgsf            # ODF/Office document thumbnails
  ];

  # 4. NixOS Polish
  # Ensures thumbnailer config files are correctly linked so Tumbler finds them
  environment.pathsToLink = [ "/share/thumbnailers" ];
}
