-- =============================================================================
-- hyprland.lua — Entry point, loads all modules
-- =============================================================================
-- Structure:
--   monitors.lua      → display outputs & scaling
--   environment.lua   → env vars, programs, autostart
--   look-and-feel.lua → gaps, borders, blur, opacity, misc
--   animations.lua    → curves, animation tree, gestures
--   keybindings.lua   → all hl.bind() calls
--   rules.lua         → window & layer rules
-- =============================================================================

require("monitors")
require("environment")
require("look-and-feel")
require("animations")
require("keybindings")
require("rules")
