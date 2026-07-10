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

  # ── 2. GTK Configuration (Reddit-Inspired Fix) ──────────────────────────────
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
      "gtk-cursor-theme-name" = "Bibata-Modern-Classic";
      "gtk-cursor-theme-size" = 24;
    };
  };

  # ── 2b. Dark mode for GTK4 / libadwaita + Chromium ──────────────────────────
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  # ── 3. Force Environment Variables ──────────────────────────────────────────
  home.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
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
}
