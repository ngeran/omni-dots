-- =============================================================================
-- look-and-feel.lua — Visual appearance, OLED optimizations, input
-- =============================================================================
-- OLED burn-in mitigation strategy:
--   - rounding = 0: no anti-aliased corner glow on OLED sub-pixels
--   - shadows disabled: bright halos = localised burn-in risk
--   - active_opacity = 0.92: reduces peak luminance on static windows
--   - inactive_opacity = 0.75: meaningful dim on unfocused windows
--   - dim_inactive = true: compositor-level dimming (separate from opacity)
--   - dim_strength = 0.15: subtle but effective; stacks with inactive_opacity
--   - borders: low-saturation teal replaces vivid cyan/green gradient
--     (still identifiable but ~40% lower peak brightness)
--   - blur.vibrancy removed: vibrancy boosts saturation → brighter pixels
--   - vrr = 2: VRR always-on reduces static refresh stress on OLED
--   - logo/wallpaper disabled: no static bright graphic on startup
-- =============================================================================

hl.config({
  -- ── Layout & borders ──────────────────────────────────────────────────────
  general = {
    gaps_in          = 1,
    gaps_out         = 1,
    border_size      = 1, -- thinner border = fewer always-lit pixels
    col              = {
      -- Single low-saturation teal; no vivid gradient to prevent bright
      -- halo around every focused window on OLED
      active_border   = "rgba(00707888)",
      inactive_border = "rgba(1a1a1a66)",
    },
    resize_on_border = false,
    allow_tearing    = false,
    layout           = "dwindle",
  },

  -- ── Decoration & OLED blur ────────────────────────────────────────────────
  decoration = {
    rounding         = 0,    -- sharp corners: zero anti-aliasing glow
    rounding_power   = 2,
    active_opacity   = 1,    -- pull peak luminance off static windows
    inactive_opacity = 0.75, -- stronger dim on unfocused content
    dim_inactive     = true, -- compositor-level dim (stacks with opacity)
    dim_strength     = 0.15, -- 15% additional dim on inactive windows
    shadow           = {
      enabled = false,       -- disabled: bright halos on OLED = bad
    },
    blur             = {
      enabled = true,
      size    = 4,
      passes  = 2,
      -- vibrancy removed: it saturates/brightens blurred regions
      noise   = 0.03, -- slightly more dither to mask banding at
      -- lower opacity levels on OLED
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
    kb_variant   = "",
    kb_model     = "",
    kb_options   = "",
    kb_rules     = "",
    follow_mouse = 1,
    sensitivity  = 0, -- 0 = no pointer acceleration
    touchpad     = {
      natural_scroll = false,
    },
  },

  -- ── Misc / OLED power management ──────────────────────────────────────────
  misc = {
    force_default_wallpaper = -1,    -- disable anime mascot
    disable_hyprland_logo   = true,  -- no static logo on OLED
    vrr                     = 2,     -- VRR always-on (best for OLED)
    focus_on_activate       = false, -- no sudden bright flashes
    mouse_move_enables_dpms = false, -- let screen sleep freely
    key_press_enables_dpms  = false,
  },

  -- ── Animations enabled globally (curves in animations.lua) ───────────────
  animations = {
    enabled = true,
  },
})
