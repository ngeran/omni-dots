-- =============================================================================
-- rules.lua — Window and layer rules
-- =============================================================================

-- ── Global suppressions ───────────────────────────────────────────────────────
hl.window_rule({
  name           = "suppress-maximize-events",
  match          = { class = ".*" },
  suppress_event = "maximize",
})

-- Fix XWayland drag-and-drop ghost windows
hl.window_rule({
  name     = "fix-xwayland-drags",
  match    = {
    class = "^$",
    title = "^$",
    xwayland = true,
    float = true,
    fullscreen = false,
    pin = false
  },
  no_focus = true,
})

-- hyprland-run floating placement
hl.window_rule({
  name  = "move-hyprland-run",
  match = { class = "hyprland-run" },
  move  = "20 monitor_h-120",
  float = true,
})

-- ── QuickShell surfaces ───────────────────────────────────────────────────────
hl.window_rule({
  name        = "quickshell-wayland",
  match       = { class = "quickshell" },
  float       = true,
  rounding    = 0,
  border_size = 0,
})

-- ── Floating Overlay Shared Logic ─────────────────────────────────────────────
-- All our overlays share these "Obsidian Core" traits (OLED friendly)
local overlay_base = {
  float = true,
  pin = true,
  center = true,
  rounding = 0,
  border_size = 1
}

-- 1. Standard TUI overlays (900x650)
local standard_tuis = { "impala-float", "bluetui-float", "wiremix-float" }

for _, cls in ipairs(standard_tuis) do
  local rule = { name = cls .. "-rule", match = { class = "^" .. cls .. "$" }, size = "900 650" }
  for k, v in pairs(overlay_base) do rule[k] = v end
  hl.window_rule(rule)
end

-- 2. Large / Custom Sized Floats
-- We define specific sizes here: Keybinds needs width, Fastfetch needs room for the logo
local custom_floats = {
  ["keybinds-float"]  = "1100 700",
  ["fastfetch-float"] = "1250 700"
}

for cls, sz in pairs(custom_floats) do
  local rule = { name = cls .. "-rule", match = { class = "^" .. cls .. "$" }, size = sz }
  for k, v in pairs(overlay_base) do rule[k] = v end
  hl.window_rule(rule)
end
