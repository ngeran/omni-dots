-- =============================================================================
-- keybindings.lua - Hyprland Key Bindings Configuration
-- =============================================================================
-- Core bindings for window management and application launching.
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
hl.bind(modShift .. " + B", hl.dsp.exec_cmd("quickshell ipc -c bar call barToggle toggle"))
hl.bind(mod .. " + P", hl.dsp.exec_cmd("quickshell ipc -c settings call powerMenu toggle"))
hl.bind(modShift .. " + T", hl.dsp.exec_cmd("quickshell ipc -c settings call SettingsWindow openControlNetwork"))
hl.bind(mod .. " + A",
  hl.dsp.exec_cmd("quickshell ipc -p ~/.config/quickshell/settings/shell.qml call SettingsWindow toggle"))

-- --- Help & Analytics --------------------------------------------------------
hl.bind(mod .. " + K", hl.dsp.exec_cmd("quickshell ipc -c bar call keybinds toggle"))
hl.bind(mod .. " + Z", hl.dsp.exec_cmd("quickshell ipc -c bar call zaiUsage toggle"))

-- --- Session Management ------------------------------------------------------
hl.bind(mod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mod .. " + M",
  hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))

-- --- Window Management (FIXED: Direct Function Calls) -------------------------

-- Toggle current window between Tiled and Floating mode
hl.bind(mod .. " + V", hl.dsp.toggle_floating())

-- Toggle orientation (Vertical/Horizontal)
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))

-- Toggle Fullscreen mode (0 = real fullscreen, 1 = maximize)
hl.bind(mod .. " + F", hl.dsp.fullscreen(0))

-- Resize Active Window (Hold Mod and + or -)
-- Using direct resizeactive function call
hl.bind(mod .. " + EQUAL", hl.dsp.resize_active(40, 40), { repeating = true })
hl.bind(mod .. " + MINUS", hl.dsp.resize_active(-40, -40), { repeating = true })


-- --- Navigation & Window Moving ----------------------------------------------
-- Move Focus between windows
hl.bind(mod .. " + LEFT",  hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + RIGHT", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + UP",    hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + DOWN",  hl.dsp.focus({ direction = "down" }))

-- Swap Windows positions (Direct Function Call)
hl.bind(modShift .. " + LEFT",  hl.dsp.move_window("l"))
hl.bind(modShift .. " + RIGHT", hl.dsp.move_window("r"))
hl.bind(modShift .. " + UP",    hl.dsp.move_window("u"))
hl.bind(modShift .. " + DOWN",  hl.dsp.move_window("d"))


-- --- Workspace Management ----------------------------------------------------
for i = 1, 10 do
  local key = i % 10
  hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
  hl.bind(modShift .. " + " .. key, hl.dsp.window.move({ workspace = i }))
end


-- --- Screenshots -------------------------------------------------------------
hl.bind(modShift .. " + S", hl.dsp.exec_cmd([[sh -c 'grim -g "$(slurp)" - | wl-copy']]))
hl.bind(mod .. " + S",
  hl.dsp.exec_cmd([[sh -c 'grim -g "$(slurp)" ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%m-%s).png']]))


-- --- Mouse Bindings -----------------------------------------------------------
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })


-- --- Hardware Controls (Audio/Brightness/Media) -------------------------------
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
