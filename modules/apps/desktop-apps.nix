{ pkgs, ... }: {
  # System / desktop-shell-level GUI tools ONLY. Creative + note apps
  # (obsidian, kicad, inkscape, krita) live in home-manager
  # (modules/apps/essentials.nix) — keep ONE source of truth per package, not
  # both the system and home layers (they had drifted into a double-install).
  #
  # Removed: inkscape-with-extensions / krita / kicad / obsidian (→ home),
  #          kitty — ghostty is the desktop's primary terminal
  #          (configs/hypr/environment.lua sets TERMINAL="ghostty"). kitty's
  #          config is still deployed by home/dotfiles.nix, so re-adding the
  #          package to the desktop is a one-liner if you miss it.
  #          hyprlock — installed by `programs.hyprlock.enable` in
  #          hosts/desktop/default.nix (the module also wires its PAM service;
  #          the bare package could never unlock).
  #          hypridle — owned by home/hypridle.nix (package + supervised
  #          systemd user unit; started by environment.lua).
  #          chromium — owned by home/chromium.nix (programs.chromium, so its
  #          keyring/NVDEC/Wayland launch flags are declarative).
  environment.systemPackages = with pkgs; [
    # --- Compositor / desktop shell ---
    ghostty        # primary terminal (Quickshell themes ~/.config/ghostty/config at runtime)
    awww           # wallpaper daemon (Quickshell may drive it; real pkg, v0.12.1)
    grim           # screenshot grabber
    slurp          # area selector

    # --- Session / hardware helpers ---
    polkit_gnome   # polkit auth agent (launched by a systemd user unit in home/quickshell.nix)
    brightnessctl  # backlight control (XF86MonBrightness* keys; environment.lua)

    # --- Media ---
    vlc
  ];
}
