-- =============================================================================
-- keybindings.lua - All hl.bind() calls
-- =============================================================================
-- Reads MAIN_MOD, TERMINAL, FILE_MANAGER, LAUNCHER from environment.lua
-- (loaded before this file via hyprland.lua require order)
-- =============================================================================

-- =============================================================================
-- AVAILABLE KEYS REFERENCE (SUPER / SUPER + SHIFT)
-- =============================================================================
-- The following keys are currently UNUSED and safe to assign in the future:
--
-- [ Letters ]
--   D, E, G, H, I, N, O, R, U, W, Y, Z
--
-- [ Modifiers Already Used / Reserved ]
--   SUPER + B       -> Reserved for future global toggle or app
--   SUPER + SHIFT + B -> QuickShell Bar Toggle
--   SUPER + Q       -> (Available again - Satty screenshot removed)
--   SUPER + SHIFT + Q -> (Available again - Grim clipboard screenshot removed)
-- =============================================================================

local mod      = MAIN_MOD -- "SUPER"
local modShift = mod .. " + SHIFT"

-- --- Core Applications -------------------------------------------------------
hl.bind(mod .. " + X", hl.dsp.exec_cmd(TERMINAL))
hl.bind(mod .. " + B", hl.dsp.exec_cmd("chromium"))
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd(LAUNCHER))
hl.bind(mod .. " + C", hl.dsp.window.close())
hl.bind(modShift .. " + F", hl.dsp.exec_cmd(FILE_MANAGER))

-- --- QuickShell IPC Toggles --------------------------------------------------
-- Bar toggle clamped to SUPER + SHIFT + B to avoid conflicts
hl.bind(modShift .. " + B", hl.dsp.exec_cmd("quickshell ipc -c bar call barToggle toggle"))

-- Power menu (settings shell)
hl.bind(mod .. " + P", hl.dsp.exec_cmd("quickshell ipc -c settings call powerMenu toggle"))

-- ControlWindow consolidated -> Settings (Bluetooth, network, set-volume)
hl.bind(modShift .. " + T", hl.dsp.exec_cmd("quickshell ipc -c settings call SettingsWindow openControlNetwork"))

-- Settings dashboard window
hl.bind(mod .. " + A",
  hl.dsp.exec_cmd("quickshell ipc -p ~/.config/quickshell/settings/shell.qml call SettingsWindow toggle"))

-- --- Help / Keybind Reference -------------------------------------------------
-- Live cheat-sheet: parses keybindings.lua on every launch, so new binds
-- (and their adjacent "-- comment" description) show up automatically.
hl.bind(mod .. " + K",
  hl.dsp.exec_cmd("kitty --class keybinds-float -e python3 ~/.config/hypr/scripts/keybinds_viewer.py"))
-- --- Session Management ------------------------------------------------------
hl.bind(mod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mod .. " + M",
  hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))

-- --- Window Management & Tiling -----------------------------------------------
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))

-- --- Focus Navigation (Arrow Keys) -------------------------------------------
hl.bind(mod .. " + LEFT", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + RIGHT", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + UP", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + DOWN", hl.dsp.focus({ direction = "down" }))

-- --- Workspace Switching & Window Moving (1-10) -------------------------------
for i = 1, 10 do
  local key = i % 10
  hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
  hl.bind(modShift .. " + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Save region to clipboard (Using an available key like 'S')
hl.bind(modShift .. " + S", hl.dsp.exec_cmd([[sh -c 'grim -g "$(slurp)" - | wl-copy']]))

-- Save region directly to a file in your Pictures directory
hl.bind(mod .. " + S",
  hl.dsp.exec_cmd([[sh -c 'grim -g "$(slurp)" ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%m-%s).png']]))

-- --- Mouse Bindings -----------------------------------------------------------
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- --- Hardware: Audio Control --------------------------------------------------
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
  { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
  { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
  { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
  { locked = true, repeating = true })

-- --- Hardware: Backlight Display ----------------------------------------------
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),
  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),
  { locked = true, repeating = true })

-- --- Hardware: Media Player Controls ------------------------------------------
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
