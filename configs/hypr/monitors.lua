-- =============================================================================
-- monitors.lua — High-Refresh OLED Config
-- =============================================================================

hl.monitor({
  output   = "HDMI-A-1",
  -- Change to 240Hz to match your MPG321UX specs. 
  -- High refresh reduces persistence-based heat on OLED pixels.
  mode     = "3840x2160@240", 
  position = "0x0",
  scale    = "1.5",
  bitdepth = 10,  -- Crucial for QD-OLED to prevent banding in dark gradients
  vrr      = 2,   -- Always-on VRR (helps OLED frame-time stability)
})
