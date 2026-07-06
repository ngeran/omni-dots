{ config, pkgs, ... }:

{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland; # Optimized for Hyprland
    
    # We point to a file that imports our layout + our dynamic colors
    theme = "~/.config/rofi/main.rasi";

    extraConfig = {
      modi = "drun,run";
      show-icons = true;
      display-drun = "";
      drun-display-format = "{name}";
      font = "Inter Nerd Font 11";
    };
  };

  # Define the layout (The "Elegant" look)
  xdg.configFile."rofi/theme.rasi".text = ''
    @import "~/.cache/theme/colors.rasi"

    window {
        width: 600px;
        border: 1px;
        border-color: @primary;
        background-color: @bg;
        border-radius: 12px;
        padding: 20px;
    }

    mainbox {
        spacing: 15px;
        children: [ inputbar, listview ];
        background-color: transparent;
    }

    inputbar {
        spacing: 10px;
        padding: 12px;
        background-color: @bg-alt;
        border-radius: 8px;
        children: [ prompt, entry ];
    }

    prompt {
        text-color: @primary;
        background-color: transparent;
    }

    entry {
        text-color: @fg;
        placeholder: "Search applications...";
        placeholder-color: @fg-dim;
        background-color: transparent;
    }

    listview {
        lines: 8;
        columns: 1;
        fixed-height: true;
        background-color: transparent;
    }

    element {
        padding: 8px;
        border-radius: 6px;
        background-color: transparent;
        text-color: @fg;
    }

    element selected {
        background-color: @primary;
        text-color: @bg;
    }

    element-icon { size: 24px; }
  '';

  # Create the entry point that Rofi actually reads
  xdg.configFile."rofi/main.rasi".text = ''
    @import "theme.rasi"
  '';
}
