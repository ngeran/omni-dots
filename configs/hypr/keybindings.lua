-- =============================================================================
-- keybindings.lua - Hyprland Key Bindings Configuration
-- =============================================================================
-- This file defines all keyboard and mouse interactions.
-- Reads MAIN_MOD, TERMINAL, FILE_MANAGER, LAUNCHER from environment.lua
-- =============================================================================

-- =============================================================================
-- AVAILABLE KEYS REFERENCE (SUPER / SUPER + SHIFT)
-- =============================================================================
-- The following keys are currently UNUSED and safe to assign in the future:
--
-- [ Letters ]
--   D, E, G, H, I, N, O, R, U, W, Y
--
-- [ Modifiers Already Used / Reserved ]
--   SUPER + B         -> Chromium
--   SUPER + SHIFT + B -> QuickShell Bar Toggle
--   SUPER + F         -> Fullscreen
--   SUPER + +/-       -> Resize
-- =============================================================================

local mod      = MAIN_MOD -- "SUPER"
local modShift = mod .. " + SHIFT"

-- --- Core Applications -------------------------------------------------------
-- Launch Terminal
hl.bind(mod .. " + X", hl.dsp.exec_cmd(TERMINAL))

-- Launch Web Browser
hl.bind(mod .. " + B", hl.dsp.exec_cmd("chromium"))

-- Launch Application Runner (Rofi/Wofi)
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd(LAUNCHER))

-- Close Focused Window
hl.bind(mod .. " + C", hl.dsp.window.close())

-- Launch File Manager
hl.bind(modShift .. " + F", hl.dsp.exec_cmd(FILE_MANAGER))


-- --- QuickShell IPC Toggles --------------------------------------------------
-- Toggle the main Status Bar
hl.bind(modShift .. " + B", hl.dsp.exec_cmd("quickshell ipc -c bar call barToggle toggle"))

-- Toggle the Power Menu (Shutdown/Restart UI)
hl.bind(mod .. " + P", hl.dsp.exec_cmd("quickshell ipc -c settings call powerMenu toggle"))

-- Open Network/Bluetooth Control Center
hl.bind(modShift .. " + T", hl.dsp.exec_cmd("quickshell ipc -c settings call SettingsWindow openControlNetwork"))

-- Toggle the main Settings Dashboard
hl.bind(mod .. " + A",
  hl.dsp.exec_cmd("quickshell ipc -p ~/.config/quickshell/settings/shell.qml call SettingsWindow toggle"))


-- --- Help / Keybind Reference -------------------------------------------------
-- Toggles the Quickshell keybinds overlay (pure QML; replaces the old python viewer)
hl.bind(mod .. " + K",
  hl.dsp.exec_cmd("quickshell ipc -c bar call keybinds toggle"))

-- --- Z.ai Usage Analytics -----------------------------------------------------
-- Toggles the Z.ai quota HUD overlay (polls api.z.ai; alerts via NotificationService)
hl.bind(mod .. " + Z",
  hl.dsp.exec_cmd("quickshell ipc -c bar call zaiUsage toggle"))


-- --- Session Management ------------------------------------------------------
-- Lock the Screen
hl.bind(mod .. " + L", hl.dsp.exec_cmd("hyprlock"))

-- Exit Session or Shutdown
hl.bind(mod .. " + M",
  hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))


-- --- Window Management & Tiling -----------------------------------------------
-- Toggle current window between Tiled and Floating mode
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))

-- Toggle the orientation of the split (Vertical/Horizontal)
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))

-- Toggle Fullscreen mode
hl.bind(mod .. " + F", hl.dsp.exec_cmd("hyprctl dispatch fullscreen 0"))

-- Resize Active Window (Hold Mod and + or -)
-- Using "repeating = true" allows holding the key down to continue resizing
hl.bind(mod .. " + EQUAL", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 40 40"), { repeating = true })
hl.bind(mod .. " + MINUS", hl.dsp.exec_cmd("hyprctl dispatch resizeactive -40 -40"), { repeating = true })


-- --- Navigation & Window Moving ----------------------------------------------
-- Move Focus between windows using Arrow Keys
hl.bind(mod .. " + LEFT",  hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + RIGHT", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + UP",    hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + DOWN",  hl.dsp.focus({ direction = "down" }))

-- Move/Swap Windows positions using Mod + Shift + Arrow Keys
hl.bind(modShift .. " + LEFT",  hl.dsp.exec_cmd("hyprctl dispatch movewindow l"))
hl.bind(modShift .. " + RIGHT", hl.dsp.exec_cmd("hyprctl dispatch movewindow r"))
hl.bind(modShift .. " + UP",    hl.dsp.exec_cmd("hyprctl dispatch movewindow u"))
hl.bind(modShift .. " + DOWN",  hl.dsp.exec_cmd("hyprctl dispatch movewindow d"))


-- --- Workspace Switching & Window Moving (1-10) -------------------------------
-- Switches to workspace N / Moves window to workspace N
for i = 1, 10 do
  local key = i % 10
  hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
  hl.bind(modShift .. " + " .. key, hl.dsp.window.move({ workspace = i }))
end


-- --- Screenshots -------------------------------------------------------------
-- Save selected region to clipboard
hl.bind(modShift .. " + S", hl.dsp.exec_cmd([[sh -c 'grim -g "$(slurp)" - | wl-copy']]))

-- Save selected region directly to Pictures folder
hl.bind(mod .. " + S",
  hl.dsp.exec_cmd([[sh -c 'grim -g "$(slurp)" ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%m-%s).png']]))


-- --- Mouse Bindings -----------------------------------------------------------
-- Scroll to switch workspaces
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Left click drag to move, Right click drag to resize
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })


-- --- Hardware: Audio Control --------------------------------------------------
-- Adjust volume using multimedia keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
  { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
  { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
  { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
  { locked = true, repeating = true })


-- --- Hardware: Backlight Display ----------------------------------------------
-- Adjust screen brightness
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),
  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),
  { locked = true, repeating = true })


-- --- Hardware: Media Player Controls ------------------------------------------
-- Control music/video playback
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
