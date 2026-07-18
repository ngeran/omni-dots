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
  -- 1. Propagate Wayland vars to D-Bus and systemd user session
  hl.exec_cmd(
    "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP QT_QPA_PLATFORM GDK_BACKEND CLUTTER_BACKEND SDL_VIDEODRIVER")
  hl.exec_cmd(
    "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP QT_QPA_PLATFORM GDK_BACKEND CLUTTER_BACKEND SDL_VIDEODRIVER")

  -- 2. Dark mode: set GTK color-scheme via gsettings
  hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
  hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark")
  hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme Adwaita")

  -- 3. Vicinae background listener
  hl.exec_cmd("mkdir -p $XDG_RUNTIME_DIR/vicinae && vicinae server &")

  -- 4. Wallpaper daemon
  hl.exec_cmd("awww-daemon")

  -- 5. Brief socket stabilisation delay
  hl.exec_cmd("sleep 0.5")

  -- 6. Wallpaper shuffler
  hl.exec_cmd("quickshell -c ~/.config/quickshell/wallpaper-service &")

  -- 7. Primary bar
  hl.exec_cmd("quickshell -c ~/.config/quickshell/bar &")

  -- 8. Settings dashboard
  hl.exec_cmd("quickshell -c ~/.config/quickshell/settings &")

  -- 9. Polkit Agent
  hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &")

  -- 10. Start Hypridle LAST
  hl.exec_cmd("sleep 2 && mkdir -p $HOME/.cache/hypr $HOME/.local/state/hypr && cp -n $HOME/.config/hypr/hypridle.conf $HOME/.cache/hypr/hypridle.conf && hypridle -c $HOME/.cache/hypr/hypridle.conf >> $HOME/.local/state/hypr/hypridle.log 2>&1 &")
end)
