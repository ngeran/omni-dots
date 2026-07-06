{ config, pkgs, ... }:

{
  # ── 1. The Pointer Engine (The "Source of Truth") ──────────────────────────
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  # ── 2. GTK Configuration (Reddit-Inspired Fix) ──────────────────────────────
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 24;
    };

    # Specific fixes for GTK3 and GTK4 consistent cursor rendering
    gtk3.extraConfig = {
      "gtk-cursor-theme-name" = "Bibata-Modern-Classic";
      "gtk-cursor-theme-size" = 24;
    };
    gtk4.extraConfig = {
      # Some versions of HM prefer an attribute set, others a string.
      # This attribute set is the modern standard:
      "gtk-cursor-theme-name" = "Bibata-Modern-Classic";
      "gtk-cursor-theme-size" = 24;
    };
  };

  # ── 2b. Dark mode for GTK4 / libadwaita + Chromium ──────────────────────────
  # gtk.theme (Adwaita-dark) above themes GTK3 only. GTK4/libadwaita apps and
  # Chromium read this GSettings key instead. It is a light/dark SWITCH only —
  # it carries no palette, so it cannot conflict with Quickshell's colors.json
  # channel (which GTK4 apps don't read) or Stylix's palette-only mode.
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  # ── 3. Force Environment Variables ──────────────────────────────────────────
  home.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
    HYPRCURSOR_THEME = "Bibata-Modern-Classic";
    HYPRCURSOR_SIZE = "24";
    # NOTE: QT_QPA_PLATFORMTHEME is intentionally NOT set here. The `qt` block
    # below owns it: qt.platformTheme.name = "gtk" makes Home Manager set it to
    # "gtk2" via qtstyleplugins (the supported way to theme Qt from GTK). Setting
    # it manually here too caused a conflicting-definition build error.
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "adwaita-dark";
  };
}
