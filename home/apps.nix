{ config, pkgs, lib, ... }:

{
  # ── 1. The Pointer Engine (The "Source of Truth") ──────────────────────────
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  # ── 2. GTK Configuration ────────────────────────────────────────────────────
  gtk = {
    enable = true;
    theme = {
      name = lib.mkForce "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    # NOTE: no `cursorTheme` here, and no gtk3/gtk4 extraConfig cursor blocks
    # (there used to be three copies of the cursor setting in this file).
    # `home.pointerCursor` above with gtk.enable=true already injects
    # gtk.cursorTheme AND writes gtk-cursor-theme-name/-size into the GTK3 and
    # GTK4 settings.ini files — verified in Home Manager's
    # modules/config/home-cursor.nix. One source of truth: the block above.
  };

  # ── 2b. Dark mode for GTK4 / libadwaita + Chromium ──────────────────────────
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  # ── 3. Cursor environment variables for Hyprland ────────────────────────────
  # XCURSOR_THEME/SIZE are deliberately NOT repeated here — home.pointerCursor
  # (section 1) exports both automatically for every session. HYPRCURSOR_* is
  # Hyprland-specific and Home Manager does not know about it, so it needs the
  # manual export for hyprcursor-based apps inside the compositor.
  home.sessionVariables = {
    HYPRCURSOR_THEME = "Bibata-Modern-Classic";
    HYPRCURSOR_SIZE = "24";
  };

  # ── 4. Qt Engine Overrides ──────────────────────────────────────────────────
  qt = {
    enable = true;
    # Tells Stylix that your custom GTK-engine mapping wins!
    platformTheme.name = lib.mkForce "gtk";
    # Tells Stylix that your explicit Adwaita style wins!
    style.name = lib.mkForce "adwaita-dark";
  };

  # ── 5. Disable Stylix Desktop Hooks for Home Manager ────────────────────────
  stylix.targets.gtk.enable = false;
  stylix.targets.qt.enable = false;
  stylix.targets.gnome.enable = false;
}
