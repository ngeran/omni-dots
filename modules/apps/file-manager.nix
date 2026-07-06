{ config, pkgs, ... }:

{
  # 1. System-wide Core Desktop Programs & Wrappers
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      thunar-archive-plugin
      thunar-volman
    ];
  };

  # 2. Thunar companion packages.
  # (Matugen was previously installed system-wide here to satisfy Quickshell's
  # `which matugen` probe. It is no longer needed: wallpaper→palette generation
  # is now handled by Stylix at build time, and the nixpkgs matugen 4.0.0 build
  # could not decode images anyway. See modules/stylix.nix.)
  environment.systemPackages = with pkgs; [
    xarchiver       # Thunar compression backend
    tumbler         # Thunar image preview daemon backend
  ];

  # 3. Enable System-Wide Storage, Mounting, and Cache D-Bus channels
  services.gvfs.enable = true;      # USB mounting & trash can channels
  services.udisks2.enable = true;   # Partition manager controller
  services.tumbler.enable = true;   # Explicit thumbnail pipeline activation
}
