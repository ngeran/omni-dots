-- =============================================================================
-- environment.lua — Improved for NixOS + OLED Longevity
-- =============================================================================

MAIN_MOD     = "SUPER"
TERMINAL     = "ghostty"
FILE_MANAGER = "thunar"
LAUNCHER     = "rofi -show drun"


-- ── Core Display & Cursor Scaling ────────────────────────────────────────────
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- ── Essential Wayland Session Variables ──────────────────────────────────────
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

-- ── Graphics Pipeline & Hardware Acceleration ───────────────────────────────
-- Forces underlying toolkits (GDK, Clutter, SDL) to render natively over Wayland
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("SDL_VIDEODRIVER", "wayland")

-- Explicitly forces Mesa to use the ultra-fast ACO shader compiler for your AMD GPU
-- hl.env("AMD_DEBUG", "use_aco")

-- Web renderer hardware acceleration fallback overrides
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- ── Qt Application Configuration ─────────────────────────────────────────────
-- Forces Qt to use Wayland natively, disables outer window chrome decoration,
-- and maps styling to your qt5ct/qt6ct design layouts.
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
-- hl.env("QT_STYLE_OVERRIDE", "Fusion")

-- ── Dark Mode Enforcement ─────────────────────────────────────────────────────
-- GTK: force dark variant globally via portal color-scheme preference
hl.env("GTK_THEME", "Adwaita:dark")
-- Electron / Chromium-based apps respect this for their own UI
hl.env("GTK_APPLICATION_PREFER_DARK_THEME", "1")

-- ── Autostart Daemons ─────────────────────────────────────────────────────────
hl.on("hyprland.start", function()
  -- 1. Propagate Wayland vars to D-Bus and systemd user session (Crucial for Greetd/Portals)
  hl.exec_cmd(
    "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP QT_QPA_PLATFORM GDK_BACKEND CLUTTER_BACKEND SDL_VIDEODRIVER AMD_DEBUG")
  hl.exec_cmd(
    "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP QT_QPA_PLATFORM GDK_BACKEND CLUTTER_BACKEND SDL_VIDEODRIVER AMD_DEBUG")

  -- 2. Dark mode: set GTK color-scheme via gsettings (affects GTK3/4 apps)
  --    and xdg-desktop-portal (affects Electron, Firefox, and portal-aware apps)
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

  -- 8. Settings dashboard (Control module now consolidated here)
  hl.exec_cmd("quickshell -c ~/.config/quickshell/settings &")

  -- 9. Polkit Agent
  hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &")

  -- 10. Start Hypridle LAST (logs → $HOME/.local/state/hypr/hypridle.log)
  hl.exec_cmd("sleep 2 && mkdir -p $HOME/.local/state/hypr && hypridle >> $HOME/.local/state/hypr/hypridle.log 2>&1 &")

  -- ControlWindow removed — consolidated into settings
end)
