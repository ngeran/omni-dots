-- =============================================================================
-- monitors.lua — QD-OLED optimized defaults (MPG321UX, 4K HDMI)
-- =============================================================================
-- Tuned for best UX + burn-in reduction (2026-08-29, via the Display panel):
--   • 119.88 Hz — the panel's real max over this HDMI link even at 8-bit
--     (240 Hz needs DSC); the old "@240" was a phantom Hyprland fell back
--     from. High refresh shortens per-frame pixel dwell.
--   • SDR desktop (no cm) — PQ-white desktops are the #1 OLED wear source;
--     HDR engages automatically for fullscreen content (see look-and-feel
--     render.cm_auto_hdr).
--   • sdr_max_luminance 120 nits — sRGB reference white when HDR is active;
--     bright enough for UX, ~2/3 lower peak than a typical 350-nit SDR clip.
--   • 10-bit — prevents banding in dark QD-OLED gradients.
--   • vrr 2 (fullscreen-only VRR) — OLED-safe: avoids the Always+HDR flicker
--     some QD-OLEDs show, still gives VRR where it matters.
-- The live values can be changed from Settings → Control → Display; STAGE
-- writes them back here.

hl.monitor({
  output   = "HDMI-A-1",
  mode     = "3840x2160@119.88",
  position = "0x0",
  scale    = "1.5",
  bitdepth = 10,               -- crucial for QD-OLED: no banding in dark gradients
  vrr      = 2,                -- fullscreen-only VRR (OLED flicker-safe)
  sdr_max_luminance = 120,     -- SDR white in HDR = sRGB reference nits
})
