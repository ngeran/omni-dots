{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # --- From Old Config ---
    inkscape-with-extensions
    krita
    kicad
    obsidian
    vlc
    
    # --- From Current Host File ---
    ghostty
    kitty
    chromium
    hyprlock
    hypridle
    awww          # Your wallpaper tool
    grim          # Screenshot grabber
    slurp         # Area selector
    # --- Notification --
    mako
  ];
}
