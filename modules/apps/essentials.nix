{ config, pkgs, lib, ... }:

let
  # =========================================================================
  # Claude Code / Z.ai gateway — single source of truth
  # =========================================================================
  # Gateway + model routing. Exported to the shell AND written to settings.json
  # so the two can never drift apart.
  claudeModelEnv = {
    ANTHROPIC_BASE_URL = "https://api.z.ai/api/anthropic";
    ANTHROPIC_DEFAULT_HAIKU_MODEL = "glm-5.3-flash[1m]";
    ANTHROPIC_DEFAULT_SONNET_MODEL = "glm-5.3[1m]";
    ANTHROPIC_DEFAULT_OPUS_MODEL = "glm-5.3[1m]";
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
  };

  # Everything written to ~/.claude/settings.json (the auth token is injected
  # at activation time from ~/.config/secrets/zai_key, never stored in Nix).
  claudeSettings = {
    env = claudeModelEnv // {
      # Compact at 200k instead of letting history grow to 1M and re-sending it every turn.
      CLAUDE_CODE_AUTO_COMPACT_WINDOW = "200000";
      API_TIMEOUT_MS = "3000000";
      MAX_THINKING_TOKENS = "10000";
      BASH_MAX_OUTPUT_LENGTH = "20000";
    };

    # Lean default set; enable heavier plugins per project in .claude/settings.json.
    enabledPlugins = {
      "context7@claude-plugins-official" = true;
      "frontend-design@claude-plugins-official" = true;
      "rtk-plugin@enix" = true;
      "claude-code-setup@claude-plugins-official" = false;
      "claude-md-management@claude-plugins-official" = false;
      "code-review@claude-plugins-official" = false;
      "code-simplifier@claude-plugins-official" = false;
      "commit-commands@claude-plugins-official" = false;
      "feature-dev@claude-plugins-official" = false;
      "figma@claude-plugins-official" = false;
      "github@claude-plugins-official" = false;
      "playwright@claude-plugins-official" = false;
      "ralph-loop@claude-plugins-official" = false;
      "security-guidance@claude-plugins-official" = false;
      "skill-creator@claude-plugins-official" = false;
      "superpowers@claude-plugins-official" = false;
      "typescript-lsp@claude-plugins-official" = false;
      "vercel@claude-plugins-official" = false;
    };

    # Keep noisy / secret / generated files out of the context window.
    permissions.deny = [
      "Read(./.env)"
      "Read(./.env.*)"
      "Read(./node_modules/**)"
      "Read(./dist/**)"
      "Read(./build/**)"
      "Read(./.astro/**)"
      "Read(./result/**)"
      "Read(./package-lock.json)"
      "Read(./pnpm-lock.yaml)"
      "Read(./uv.lock)"
      "Read(./flake.lock)"
    ];
  };
in
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

    # System Tools
    btop
    # Backend for the quickshell bar's omarchy-xray plugin (JSON-lines
    # inspector). NOT in velocity's runtimeInputs — owned here.
    python3

    # wl-copy/wl-paste for the IN-REPO consumers: the screenshot keybind
    # (configs/hypr/keybindings.lua: grim -g "$(slurp)" - | wl-copy) and
    # nixvim's clipboard provider (modules/apps/nixvim/default.nix). The
    # velocity HM module also ships wl-clipboard (same store path) — kept
    # here so those two survive even if programs.velocity is ever disabled.
    wl-clipboard

    # REMOVED (dedupe 2026-11-21): qrencode / cliphist / wf-recorder used to
    # be installed here "for the bar" — velocity's HM module ships all three
    # (runtimeInputs are installed into the user profile too, nix/hm-module.nix).
    # One owner: if velocity is disabled, its tools die with it — correctly.

    # Creative & Engineering Suite — the SINGLE source of truth for these
    # (NOT also in modules/apps/desktop-apps.nix; dedup'd so the two layers
    # can't drift). inkscape-with-extensions is the superset of plain inkscape.
    kicad
    # Disabled (NOT removed) 2026-10-18 — replaced by the ArtCraft suite
    # (home/artcraft/: photocraft/vectorcraft/pdfcraft). Uncomment to
    # restore.
    # inkscape-with-extensions
    # krita

    # NOTE: openssh client removed — services.openssh.enable (modules/ssh.nix)
    # already ships `ssh`/`scp`/`sftp` in the system profile
    # (/run/current-system/sw/bin/ssh). The home-level package was redundant.

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

    # Your original configuration mapped natively into Nix. Deliberate
    # differences from it are commented where they live.
    settings = {
      add_newline = true;
      command_timeout = 200;
      # An explicit top-level `format` replaces starship's whole default
      # prompt, so a module that is not listed here is never drawn. $hostname
      # leads: the same user is on every machine, so the hostname is the only
      # thing that says which one this prompt belongs to.
      format = "$hostname[$directory$git_branch$git_status]($style)$character";

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
        # conflicted / up_to_date / modified are Nerd Font glyphs, as in
        # upstream Omarchy; they render blank in a plain font.
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

      # Names the machine, but only inside an SSH session: the local prompt
      # stays as it is and every remote prompt starts with the ssh symbol and
      # the hostname. ssh_only is starship's default too; written out so the
      # choice is visible. It keys off the SSH_CONNECTION / SSH_CLIENT /
      # SSH_TTY variables, so a shell without them shows no label.
      hostname = {
        ssh_only = true;
        format = "[$ssh_symbol$hostname]($style) ";
        style = "bold yellow";
      };
    };
  };

  # =========================================================================
  # 3. Secure Infrastructure & Identity Routing (SSH)
  # =========================================================================
  # Multiple GitHub identities on one machine. The default `github.com` host
  # keeps using the primary key (id_github); the aliases (`github-ggeran069`,
  # `github-calgreece`) route to the same server but each presents its own
  # key. Use the alias in clone URLs, e.g.:
  #     git clone git@github-ggeran069:ggeran069/<repo>.git
  #
  # `IdentitiesOnly yes` matters: without it, ssh-agent offers every loaded key
  # in turn and GitHub rejects the connection with "Too many authentication
  # failures" before it ever tries the right one.
  home.file.".ssh/config".text = ''
  # k8s-lab VMs (libvirt NAT 192.168.122.0/24): root + the lab key only
  # (cloud-init bakes this key for root; there is no other account).
  # Two blocks so BOTH forms work: `ssh root@192.168.122.10` and `ssh cp-1`.
  # accept-new: new VMs (fresh host keys after a repave) connect without a
  # prompt, while a CHANGED key on a known host still refuses — same safety
  # as before, rescue via `ssh-keygen -R 192.168.122.<X>` (documented in the
  # lab runbook §1.7).
    Host 192.168.122.10 192.168.122.21 192.168.122.22
        User root
        IdentityFile ${config.home.homeDirectory}/.ssh/k8s-lab_ed25519
        IdentitiesOnly yes
        StrictHostKeyChecking accept-new

    Host cp-1 worker-1 worker-2
        User root
        IdentityFile ${config.home.homeDirectory}/.ssh/k8s-lab_ed25519
        IdentitiesOnly yes
        StrictHostKeyChecking accept-new

    Host cp-1
        HostName 192.168.122.10
    Host worker-1
        HostName 192.168.122.21
    Host worker-2
        HostName 192.168.122.22

    Host github.com
        HostName github.com
        User git
        IdentityFile ${config.home.homeDirectory}/.ssh/id_github
        IdentitiesOnly yes

    Host github-ggeran069
        HostName github.com
        User git
        IdentityFile ${config.home.homeDirectory}/.ssh/ggeran069
        IdentitiesOnly yes

    Host github-calgreece
        HostName github.com
        User git
        IdentityFile ${config.home.homeDirectory}/.ssh/calgreece
        IdentitiesOnly yes
  '';

  # =========================================================================
  # 4. Claude Code / Z.ai Engine Gateway Orchestration
  # =========================================================================
  # Gateway + model routing for the shell (same values as settings.json env).
  # The auth token is deliberately NOT exported here.
  home.sessionVariables = claudeModelEnv;

  # Generates ~/.claude/settings.json:
  #   - declared settings above are merged over whatever already exists, so
  #     keys Claude Code adds itself survive, while declared keys always win
  #   - the API key is read from the secret file and injected with jq --arg
  #     (no shell/JSON escaping hazards)
  #   - written with umask 077 to a temp file, then moved into place atomically
  # To fully reset the file, delete it and re-run the switch.
  home.activation.configure-claude = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    SECRET_FILE="${config.home.homeDirectory}/.config/secrets/zai_key"
    TARGET_DIR="${config.home.homeDirectory}/.claude"
    TARGET_FILE="$TARGET_DIR/settings.json"
    JQ="${pkgs.jq}/bin/jq"

    if [ ! -s "$SECRET_FILE" ]; then
      echo "configure-claude: $SECRET_FILE missing or empty; leaving $TARGET_FILE untouched" >&2
    else
      ZAI_KEY=$(tr -d '\n\r ' < "$SECRET_FILE")
      mkdir -p "$TARGET_DIR"

      EXISTING='{}'
      if [ -s "$TARGET_FILE" ] && "$JQ" -e . "$TARGET_FILE" >/dev/null 2>&1; then
        EXISTING=$(cat "$TARGET_FILE")
      fi

      OLD_UMASK=$(umask)
      umask 077
      TMP_FILE=$(mktemp "$TARGET_DIR/settings.json.XXXXXX")
      umask "$OLD_UMASK"

      if printf '%s' "$EXISTING" | "$JQ" \
          --arg key "$ZAI_KEY" \
          --argjson declared ${lib.escapeShellArg (builtins.toJSON claudeSettings)} \
          '. * $declared | .env.ANTHROPIC_AUTH_TOKEN = $key' > "$TMP_FILE"; then
        chmod 600 "$TMP_FILE"
        mv -f "$TMP_FILE" "$TARGET_FILE"
      else
        echo "configure-claude: jq failed; leaving $TARGET_FILE untouched" >&2
        rm -f "$TMP_FILE"
      fi
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
