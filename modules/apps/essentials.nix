{ config, pkgs, lib, ... }:

{
  # =========================================================================
  # 1. User Application Workspace (Home Manager Packages)
  # =========================================================================
  home.packages = with pkgs; [
    # Modern CLI Alternatives & Utilities
    eza
    tree
    obsidian
    fastfetch

    # Application Launcher (Merged back into upstream for 26.05)
    rofi

    # Creative & Engineering Suite
    kicad
    inkscape
    krita
    # Network Security
    openssh
  ];

  # Modern eza aliases to completely replace standard ls
  programs.bash.shellAliases = {
    ls = "eza --icons --group-directories-first";
    ll = "eza -lbhHigUmuSa --time-style=long-iso --git --color-scale";
    lt = "eza --tree --level=2";
  };

  # =========================================================================
  # 2. Native, Declarative Starship Prompt Engine
  # =========================================================================
  programs.starship = {
    enable = true;
    enableBashIntegration = true;

    # Your exact configuration mapped natively into Nix
    settings = {
      add_newline = true;
      command_timeout = 200;
      format = "[$directory$git_branch$git_status]($style)$character";

      character = {
        error_symbol = "[✗](bold cyan)";
        success_symbol = "[❯](bold cyan)";
      };

      directory = {
        truncation_length = 2;
        truncation_symbol = "…/";
        repo_root_style = "bold cyan";
        repo_root_format = "[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) ";
      };

      git_branch = {
        format = "[$branch]($style) ";
        style = "italic cyan";
      };

      git_status = {
        format = "[$all_status]($style)";
        style = "cyan";
        ahead = "⇡\${count} ";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count} ";
        behind = "⇣\${count} ";
        conflicted = " ";
        up_to_date = " ";
        untracked = "? ";
        modified = " ";
        stashed = "";
        staged = "";
        renamed = "";
        deleted = "";
      };
    };
  };

  # =========================================================================
  # 3. Secure Infrastructure & Identity Routing (SSH)
  # =========================================================================
  home.file.".ssh/config".text = ''
    Host github.com
        HostName github.com
        User git
        IdentityFile ${config.home.homeDirectory}/.ssh/id_github
        IdentitiesOnly yes
  '';
# =========================================================================
  # 4. Claude Code / Z.ai Engine Gateway Orchestration
  # =========================================================================
  # Forces your system environment to bypass standard Anthropic authentication
  home.sessionVariables = {
    ANTHROPIC_BASE_URL = "https://api.z.ai/api/anthropic";
    ANTHROPIC_DEFAULT_HAIKU_MODEL = "glm-4.7";
    ANTHROPIC_DEFAULT_SONNET_MODEL = "glm-5.2[1m]";
    ANTHROPIC_DEFAULT_OPUS_MODEL = "glm-5.2[1m]";
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
  };

  home.activation.configure-claude = lib.hm.dag.entryAfter ["writeBoundary"] ''
    SECRET_FILE="${config.home.homeDirectory}/.config/secrets/zai_key"
    TARGET_DIR="${config.home.homeDirectory}/.claude"
    TARGET_FILE="$TARGET_DIR/settings.json"

    if [ -f "$SECRET_FILE" ]; then
      ZAI_KEY=$(tr -d '\n\r ' < "$SECRET_FILE")
      mkdir -p "$TARGET_DIR"
      rm -f "$TARGET_FILE"
      
      cat << EOF > "$TARGET_FILE"
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "$ZAI_KEY",
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.7",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-5.2[1m]",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-5.2[1m]",
    "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "1000000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": 1,
    "API_TIMEOUT_MS": "3000000"
  }
}
EOF
      chmod 600 "$TARGET_FILE"
    fi
  '';

  # =========================================================================
  # 5. Display Safety Presets (Ultra-Safe OLED Color Profile)
  # =========================================================================
  # Seed ~/.cache/theme/colors.json ONCE as a real, writable file.
  #
  # This file is the LIVE theme channel between the settings process and the
  # bar: settings writes it on every theme change, and bar/config/ThemeConfig.qml
  # watches it via FileView.onFileChanged. It MUST stay runtime-writable.
  #
  # We therefore cannot use home.file here — home.file symlinks the target
  # read-only into the Nix store, which silently broke live theme switching
  # after the NixOS migration (settings' `printf > colors.json` failed, so the
  # file never changed and the bar's FileView never fired). The activation
  # script writes the default ONLY when the file is absent, so a user's live
  # theme choice is never clobbered on switch.
  home.activation.seedThemeColors =
    let
      defaultTheme = {
        colors = {
          background = "#000000";
          surface = "#000000";
          surfaceVariant = "#000000";
          surfaceContainer = "#000000";
          text = "#e0e0e0";
          textDim = "#808080";
          border = "#1a1a1a";
          outline = "#2a2a2a";
          outlineVariant = "#1a1a1a";
          primary = "#7c6bf0";
          secondary = "#00dce5";
          accent = "#f87171";
          success = "#34d399";
          warning = "#fbbf24";
          error = "#f87171";
          info = "#00dce5";
        };
        metadata = {
          name = "OLED Pure Black";
          source = "preset";
          applied = "";
          oledClamp = true;
          matugenEnabled = false;
        };
      };
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -f "$HOME/.cache/theme/colors.json" ]; then
        mkdir -p "$HOME/.cache/theme"
        printf '%s' ${lib.escapeShellArg (builtins.toJSON defaultTheme)} > "$HOME/.cache/theme/colors.json"
      fi
    '';

  # Seed a default ~/.config/hypr/quickshell-colors.conf — the lock screen's
  # themed background + input-field, sourced by hyprlock.conf — ONLY when absent.
  # Quickshell's ThemeService overwrites it with the live palette at login / on
  # every theme change; this just guarantees hyprlock always has a password box
  # to render, even on a fresh boot before the settings process has run. Mirrors
  # seedThemeColors above. Keep the input-field geometry in sync with the writer
  # in ~/.config/quickshell/settings/services/ThemeService.qml.
  home.activation.seedHyprlockColors =
    let
      # Neutral static fallback (same shape as the ThemeService block).
      defaultHyprlockColors = ''
        # Managed by QuickShell ThemeService — sourced at END of hyprlock.conf.
        # Seeded default; overwritten with the live theme at login.
        background {
            color = rgba(000000ff)
        }
        input-field {
            monitor =
            size = 400, 50
            position = 0, 0
            halign = center
            valign = center
            rounding = 16
            outline_thickness = 2
            inner_color = rgba(0f0f0fff)
            outer_color = rgba(2d2d2dff)
            font_color = rgba(ebebebff)
            font_family = JetBrainsMono Nerd Font
            placeholder_text = Enter Password
            fail_text = <i>$FAIL ($ATTEMPTS)</i>
            shadow_passes = 0
            fade_on_empty = false
        }
      '';
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -f "$HOME/.config/hypr/quickshell-colors.conf" ]; then
        mkdir -p "$HOME/.config/hypr"
        printf '%s' ${lib.escapeShellArg defaultHyprlockColors} > "$HOME/.config/hypr/quickshell-colors.conf"
      fi
    '';
}
