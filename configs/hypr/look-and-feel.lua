-- =============================================================================
-- look-and-feel.lua — Visual appearance & OLED optimizations
-- =============================================================================
-- STRATEGY FOR OLED LONGEVITY:
-- 1. No Shadows: Prevents high-brightness "halos" that cause uneven wear.
-- 2. Sharp Corners (Rounding 0): Anti-aliasing on corners keeps sub-pixels lit 
--    at varying intensities; sharp corners minimize this "bleed."
-- 3. Aggressive Dimming: Inactive windows are dimmed significantly (25%) to 
--    lower the overall panel voltage and heat.
-- 4. Low Saturation Borders: Vivid colors (Cyan/Magenta) wear out Blue OLED 
--    pixels fastest. Teal/Dark-Grey is used to minimize high-frequency wear.
-- 5. VRR (Variable Refresh Rate): Helps prevent static refresh artifacts.
-- =============================================================================

hl.config({
  -- ── Layout & Borders ──────────────────────────────────────────────────────
  general = {
    gaps_in          = 1,
    gaps_out         = 1,
    border_size      = 1, -- Minimalist border = fewer lit pixels
    col              = {
      active_border   = "rgba(00707888)", -- Desaturated teal
      inactive_border = "rgba(1a1a1a66)", -- Very dark grey
    },
    resize_on_border = false,
    allow_tearing    = false,
    layout           = "dwindle", -- Required for the 'resizeactive' bindings
  },

  -- ── Decoration & OLED Blur ────────────────────────────────────────────────
  decoration = {
    rounding         = 0,    -- Disabled to prevent pixel-smearing on OLED
    rounding_power   = 2,
    active_opacity   = 1.0,  
    inactive_opacity = 0.75, -- Heavily dim unfocused content
    dim_inactive     = true, -- Compositor-level dimming
    dim_strength     = 0.15, -- 15% additional darkening
    shadow           = {
      enabled = false,       -- High burn-in risk; kept OFF
    },
    blur             = {
      enabled = true,
      size    = 4,
      passes  = 2,
      noise   = 0.03, -- Dithering helps prevent banding on dark OLED backgrounds
    },
  },

  -- ── Tiling Layout Logic ───────────────────────────────────────────────────
  dwindle = {
    preserve_split = true,
  },
  master = {
    new_status = "master",
  },
  scrolling = {
    fullscreen_on_one_column = true,
  },

  -- ── Input Configuration ───────────────────────────────────────────────────
  input = {
    kb_layout    = "us",
    follow_mouse = 1,
    sensitivity  = 0, 
    touchpad     = {
      natural_scroll = false,
    },
  },

  -- ── Misc / Power Management ───────────────────────────────────────────────
  misc = {
    force_default_wallpaper = 0,    -- Disabled default graphics
    disable_hyprland_logo   = true,  -- No static logo during boot
    vrr                     = 2,     -- VRR Always-on (Reduces panel stress)
    focus_on_activate       = false, -- Prevents accidental bright window popups
    mouse_move_enables_dpms = false, -- Screen won't wake just because desk shook
    key_press_enables_dpms  = false, -- Screen stays asleep unless intended
  },

  -- ── Global Animations ─────────────────────────────────────────────────────
  animations = {
    enabled = true,
  },
})
