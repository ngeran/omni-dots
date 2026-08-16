-- =============================================================================
-- environment.lua — Improved for NixOS + OLED Longevity
-- =============================================================================

MAIN_MOD     = "SUPER"
TERMINAL     = "ghostty"
FILE_MANAGER = "thunar"
LAUNCHER     = "rofi -show drun -mesg 'ENTER  RUN     ESC  EXIT     SYSTEM_READY'"


-- ── Core Display & Cursor Scaling ────────────────────────────────────────────
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- ── Essential Wayland Session Variables ──────────────────────────────────────
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

-- ── Graphics Pipeline & Hardware Acceleration ───────────────────────────────
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- ── Qt Application Configuration ─────────────────────────────────────────────
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")

-- ── Dark Mode Enforcement ─────────────────────────────────────────────────────
hl.env("GTK_THEME", "Adwaita:dark")
hl.env("GTK_APPLICATION_PREFER_DARK_THEME", "1")

-- ── Autostart Daemons ─────────────────────────────────────────────────────────
hl.on("hyprland.start", function()
  -- 1. Propagate Wayland vars to D-Bus and the systemd user session, then
  --    start the session services deterministically once the environment is
  --    imported. All three are systemd user services (see home/quickshell.nix
  --    and home/hypridle.nix); chaining with && guarantees ordering without
  --    racing the import. exec_cmd is async, so this is a single shell chain.
  --    HYPRLAND_INSTANCE_SIGNATURE is included so services can find the
  --    compositor's IPC socket under $XDG_RUNTIME_DIR/hypr/<signature>/.
  --    Starting an already-running unit is a no-op, which also prevents
  --    duplicate instances across Hyprland restarts.
  hl.exec_cmd(
    "dbus-update-activation-environment --systemd WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP QT_QPA_PLATFORM GDK_BACKEND CLUTTER_BACKEND SDL_VIDEODRIVER"
      .. " && systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP QT_QPA_PLATFORM GDK_BACKEND CLUTTER_BACKEND SDL_VIDEODRIVER"
      .. " && systemctl --user start quickshell-bar quickshell-settings hypridle")

  -- 2. Dark mode: set GTK color-scheme via gsettings
  hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
  hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark")
  hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme Adwaita")

  -- 3. Wallpaper daemon
  hl.exec_cmd("awww-daemon")
end)
