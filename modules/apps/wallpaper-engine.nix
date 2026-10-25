{ config, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.services.wallpaperEngine;

  runtimeDeps = with pkgs; [
    mpvpaper
    mpv
    ffmpeg
    socat
    jq
    coreutils
    findutils
    gnused
  ];

  # Gate ExecStart on a Wayland socket existing — mirrors home/quickshell.nix.
  # This host runs Hyprland OUTSIDE systemd: graphical-session.target never
  # activates, so the unit is wantedBy default.target and may start BEFORE the
  # compositor creates its socket. Without the gate mpvpaper dies with "could
  # not connect to display" and the unit crash-loops. Two probes: the
  # session-declared $WAYLAND_DISPLAY first, then any wayland-* socket.
  # 120 x 0.5 s = up to 60 s, inside systemd's default TimeoutStartSec (90 s).
  waitWayland = pkgs.writeShellApplication {
    name = "wallpaper-engine-wait-wayland";
    runtimeInputs = [ pkgs.coreutils ];   # seq, sleep, id
    text = ''
      rt="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      for _ in $(seq 1 120); do
        if [ -n "$WAYLAND_DISPLAY" ] && [ -S "$rt/$WAYLAND_DISPLAY" ]; then exit 0; fi
        for w in "$rt"/wayland-*; do
          if [ -S "$w" ]; then exit 0; fi
        done
        sleep 0.5
      done
      echo "wallpaper-engine: no Wayland socket in $rt (WAYLAND_DISPLAY=''${WAYLAND_DISPLAY:-unset})" >&2
      exit 1
    '';
  };

  # Thin wrapper: bakes module options in as defaults (still overridable from
  # the shell) and puts every dependency on PATH, then runs the script.
  engine = pkgs.writeShellScriptBin "wallpaper-engine" ''
    export PATH=${lib.makeBinPath runtimeDeps}:/run/current-system/sw/bin:$PATH
    export WE_DIR="''${WE_DIR:-${cfg.directory}}"
    export WE_INTERVAL="''${WE_INTERVAL:-${toString cfg.interval}}"
    export WE_TICK="''${WE_TICK:-${toString cfg.tick}}"
    export WE_HWDEC="''${WE_HWDEC:-${cfg.hwdec}}"
    export WE_GAMMA="''${WE_GAMMA:-${toString cfg.gamma}}"
    export WE_PANSCAN="''${WE_PANSCAN:-${cfg.panscan}}"
    export WE_OUTPUTS="''${WE_OUTPUTS:-${lib.concatStringsSep " " cfg.outputs}}"
    export WE_SHUFFLE="''${WE_SHUFFLE:-${if cfg.shuffle then "1" else "0"}}"
    export WE_AUTOSTART="''${WE_AUTOSTART:-${if cfg.autostart then "1" else "0"}}"
    exec ${pkgs.bash}/bin/bash ${./wallpaper-engine.sh} "$@"
  '';
in
{
  options.services.wallpaperEngine = {
    enable = mkEnableOption "animated wallpaper engine (mpvpaper), driven by Quickshell's WallpaperService";

    directory = mkOption {
      type = types.str;
      default = "$HOME/Pictures/Live-Wallpapers";
      description = "Folder scanned for mp4/webm/mkv/mov/gif/webp/apng (expanded by the shell at runtime).";
    };

    interval = mkOption {
      type = types.ints.positive;
      default = 900;
      description = "Seconds each wallpaper stays on screen. Only used when autostart is on (standalone mode).";
    };

    tick = mkOption {
      type = types.ints.positive;
      default = 20;
      description = "Watchdog granularity in seconds — how often dead mpvpaper instances are healed.";
    };

    hwdec = mkOption {
      type = types.str;
      default = "auto-safe";
      description = "mpv hwdec mode. Try \"nvdec\" or \"nvdec-copy\" on NVIDIA, \"no\" to force software.";
    };

    gamma = mkOption {
      type = types.ints.between (-100) 100;
      default = 0;
      description = "mpv gamma. Negative values dim midtones while keeping pure black at zero (good for OLED).";
    };

    panscan = mkOption {
      type = types.str;
      default = "1.0";
      description = "1.0 fills the screen (crops), 0 letterboxes.";
    };

    outputs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "DP-1" ];
      description = "Monitor names. Empty = autodetect through hyprctl.";
    };

    shuffle = mkOption {
      type = types.bool;
      default = true;
      description = "Shuffle the playlist each cycle (standalone mode).";
    };

    autostart = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Standalone mode. When false (integrated — the default here), the daemon
        never picks media itself: Quickshell's WallpaperService drives every
        transition via `set`, and the daemon only keeps mpvpaper instances
        alive (crash recovery, monitor hotplug).
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ engine ];

    systemd.user.services.wallpaper-engine = {
      description = "Animated wallpaper engine (mpvpaper watchdog)";
      # NOT graphical-session.target: it never activates on this host (Hyprland
      # runs outside systemd — see home/quickshell.nix). default.target +
      # ExecStartPre socket gate replaces it.
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStartPre = "${waitWayland}/bin/wallpaper-engine-wait-wayland";
        ExecStart = "${engine}/bin/wallpaper-engine daemon";
        Restart = "on-failure";
        RestartSec = 3;
      };
    };
  };
}
