-- =============================================================================
-- rules.lua — Window behavior, workspace mapping, and OLED overrides
-- =============================================================================

-- ── 1. Global System Fixes ───────────────────────────────────────────────────
-- Prevent applications from trying to maximize themselves (causes tiling flickers)
hl.window_rule({
  name           = "suppress-maximize-events",
  match          = { class = ".*" },
  suppress_event = "maximize",
})

-- Fix XWayland "ghost" windows created during drag-and-drop operations
hl.window_rule({
  name     = "fix-xwayland-drags",
  match    = {
    class = "^$",
    title = "^$",
    xwayland = true,
    float = true,
  },
  no_focus = true,
})

-- ── 2. Creative Suite: DaVinci Resolve ───────────────────────────────────────
-- Resolve is an XWayland app. These rules ensure popups float and colors 
-- remain accurate despite global OLED dimming settings.

-- Main Application Window
hl.window_rule({
  name = "davinci-resolve-main",
  match = { class = "resolve" },
  -- OLED Override: Disable dimming/opacity for Resolve. 
  -- We need 100% luminance and no transparency for accurate color grading.
  active_opacity   = 1.0,
  inactive_opacity = 1.0, 
  dim_inactive     = false,
})

-- Dialogs & Popups
-- Ensures splash screen, project manager, and preferences don't tile.
hl.window_rule({
  name = "davinci-resolve-popups",
  match = { 
    class = "resolve", 
    title = "^(Welcome to DaVinci Resolve|Project Manager|.*Preferences.*|.*Pop-up.*)$" 
  },
  float  = true,
  center = true,
  pin    = true,
})

-- ── 3. System Utilities & UI Surfaces ────────────────────────────────────────

-- hyprland-run: Small floating runner near the bottom-left
hl.window_rule({
  name  = "move-hyprland-run",
  match = { class = "hyprland-run" },
  move  = "20 monitor_h-120",
  float = true,
})

-- QuickShell: The Bar, Wallpaper, and Dashboards
hl.window_rule({
  name        = "quickshell-wayland",
  match       = { class = "quickshell" },
  float       = true,
  rounding    = 0,
  border_size = 0,
})

-- ── 4. Floating Overlays (Shared Logic) ───────────────────────────────────────
-- These rules apply "Obsidian Core" traits to our TUI and UI overlays.

local overlay_base = {
  float       = true,
  pin         = true,
  center      = true,
  rounding    = 0,
  border_size = 1
}

-- 4.1 Standard TUI Overlays (e.g., Bluetooth, Mixer, Wi-Fi)
local standard_tuis = { "impala-float", "bluetui-float", "wiremix-float" }

for _, cls in ipairs(standard_tuis) do
  local rule = { name = cls .. "-rule", match = { class = "^" .. cls .. "$" }, size = "900 650" }
  for k, v in pairs(overlay_base) do rule[k] = v end
  hl.window_rule(rule)
end

-- 4.2 Large / Custom Sized Overlays
local custom_floats = {
  ["keybinds-float"]  = "1100 700",
  ["fastfetch-float"] = "1250 700",
  ["btop-float"]      = "1000 700"
}

for cls, sz in pairs(custom_floats) do
  local rule = { name = cls .. "-rule", match = { class = "^" .. cls .. "$" }, size = sz }
  for k, v in pairs(overlay_base) do rule[k] = v end
  hl.window_rule(rule)
end
