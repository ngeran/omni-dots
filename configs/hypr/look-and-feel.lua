-- =============================================================================
-- look-and-feel.lua — Visual appearance, OLED optimizations, input
-- =============================================================================
-- OLED burn-in mitigation strategy:
--   - rounding = 0: no anti-aliased corner glow on OLED sub-pixels
--   - active_opacity = 0.92: reduces peak luminance on static windows
--   - inactive_opacity = 0.75: meaningful dim on unfocused windows
--   - vrr = 2: VRR always-on reduces static refresh stress on OLED
-- =============================================================================

hl.config({
  -- ── Layout & borders ──────────────────────────────────────────────────────
  general = {
    gaps_in          = 1,
    gaps_out         = 1,
    border_size      = 1, 
    col              = {
      active_border   = "rgba(00707888)",
      inactive_border = "rgba(1a1a1a66)",
    },
    resize_on_border = false,
    allow_tearing    = false,
    layout           = "dwindle",
  },

  -- ── Decoration & OLED blur ────────────────────────────────────────────────
  decoration = {
    rounding         = 0,    
    rounding_power   = 2,
    active_opacity   = 0.92, -- RESTORED: Your original value
    inactive_opacity = 0.75, 
    dim_inactive     = true, 
    dim_strength     = 0.15, 
    shadow           = {
      enabled = false,       
    },
    blur             = {
      enabled = true,
      size    = 4,
      passes  = 2,
      noise   = 0.03, 
    },
  },

  -- ── Tiling layouts ────────────────────────────────────────────────────────
  dwindle = {
    preserve_split = true,
  },
  master = {
    new_status = "master",
  },
  scrolling = {
    fullscreen_on_one_column = true,
  },

  -- ── Input ─────────────────────────────────────────────────────────────────
  input = {
    kb_layout    = "us",
    follow_mouse = 1,
    sensitivity  = 0, 
    touchpad     = {
      natural_scroll = false,
    },
  },

  -- ── Misc / OLED power management ──────────────────────────────────────────
  misc = {
    force_default_wallpaper = -1,    
    disable_hyprland_logo   = true,  
    vrr                     = 2,     
    focus_on_activate       = false, 
    mouse_move_enables_dpms = false, 
    key_press_enables_dpms  = false,
  },

  -- ── Animations enabled globally (curves in animations.lua) ───────────────
  animations = {
    enabled = true,
  },
})
