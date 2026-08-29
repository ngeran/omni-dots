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
  -- ── XWayland High-DPI Fix ──────────────────────────────────────────────────
  -- Prevents Hyprland from pixel-stretching X11 apps like DaVinci Resolve.
  -- This forces the application to use the native screen resolution directly,
  -- allowing your Nix wrapper's 144 DPI text settings to render perfectly sharp.
  xwayland = {
    force_zero_scaling = true,
  },

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
    shadow = {
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
    kb_layout    = "us,gr",
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
    vrr                     = 2,     -- fullscreen-only VRR (0 off / 1 always / 2 fullscreen)
    focus_on_activate       = false, 
    mouse_move_enables_dpms = false, 
    key_press_enables_dpms  = false,
  },

  -- ── Animations enabled globally (curves in animations.lua) ───────────────
  animations = {
    enabled = true,
  },

  -- ── Colour management (QD-OLED burn-in policy) ───────────────────────────
  -- Desktop stays SDR (cm unset in monitors.lua = srgb) so static UI pixels
  -- never ride the PQ curve; fullscreen games/video switch to HDR on their
  -- own. Explicit (vs relying on Hyprland's default) so the policy survives
  -- upstream default changes. Toggle live in Settings → Control → Display.
  render = {
    cm_auto_hdr = 1,
  },
})
