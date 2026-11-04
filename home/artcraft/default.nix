# =============================================================================
# ArtCraft suite (PhotoCraft, VectorCraft, PdfCraft, ...)
# =============================================================================
# Apps are pinned in ./versions.json (version + AppImage URL + SRI hash) and
# wrapped with appimageTools.wrapType2, so they run on NixOS without FHS hacks.
#
#   artcraft-check    compares the ACTIVATED versions with the newest GitHub
#                     release and writes $XDG_STATE_HOME/artcraft/status.json
#                     (read by the Quickshell nikos.artcraft plugin).
#   artcraft-upgrade  bumps versions.json for the selected apps, then runs the
#                     privileged /etc/artcraft-switch wrapper (nixos-rebuild).
#   artcraft-check.timer runs the check periodically.
#
# Apps whose hash/url are empty are skipped, so the very first switch works.
# The first `artcraft-upgrade` fills everything in.
# =============================================================================
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.artcraft;

  versions = builtins.fromJSON (builtins.readFile ./versions.json);

  # Only apps that have been pinned at least once get built.
  ready = lib.filterAttrs (_: a: (a.hash or "") != "" && (a.url or "") != "") versions;

  mkApp = name: a:
    let
      src = pkgs.fetchurl { inherit (a) url hash; };
      app = pkgs.appimageTools.wrapType2 {
        pname = name;
        inherit (a) version;
        inherit src;
        # Rust/wgpu GUI apps: Vulkan, Wayland/X11 input, audio and fonts.
        extraPkgs = p: with p; [
          vulkan-loader
          libxkbcommon
          wayland
          libGL
          alsa-lib
          fontconfig
        ];
      };
      desktop = pkgs.makeDesktopItem {
        inherit name;
        desktopName = a.displayName or name;
        exec = name;
        categories = [ "Graphics" ];
      };
    in
    [ app desktop ];

  env = {
    ARTCRAFT_VERSIONS_FILE = cfg.versionsPath;
    ARTCRAFT_INSTALLED_FILE = "${config.xdg.stateHome}/artcraft/installed.json";
    ARTCRAFT_SWITCH = cfg.switchCommand;
  };

  artcraft-check = pkgs.writeShellApplication {
    name = "artcraft-check";
    runtimeInputs = with pkgs; [ curl jq coreutils libnotify ];
    runtimeEnv = env;
    text = builtins.readFile ./scripts/artcraft-check.sh;
  };

  artcraft-upgrade = pkgs.writeShellApplication {
    name = "artcraft-upgrade";
    runtimeInputs = with pkgs; [ curl jq coreutils util-linux nix artcraft-check ];
    runtimeEnv = env;
    text = builtins.readFile ./scripts/artcraft-upgrade.sh;
  };

  servicePath = lib.concatStringsSep ":" [
    "${config.home.profileDirectory}/bin"
    "/run/wrappers/bin"
    "/run/current-system/sw/bin"
  ];
in
{
  options.programs.artcraft = {
    enable = lib.mkEnableOption "the ArtCraft suite with update checking";

    versionsPath = lib.mkOption {
      type = lib.types.str;
      example = "/home/nikos/.omni-nix/home/artcraft/versions.json";
      description = ''
        Absolute path of the WRITABLE versions.json in your flake checkout. It
        must be the same file this module reads (./versions.json) and it should
        be tracked by git.
      '';
    };

    switchCommand = lib.mkOption {
      type = lib.types.str;
      default = "/etc/artcraft-switch";
      description = ''
        Privileged wrapper that runs `nixos-rebuild switch` for the flake.
        artcraft-upgrade calls it with `sudo -n`; the matching NOPASSWD rule
        lives in the host configuration.
      '';
    };

    checkInterval = lib.mkOption {
      type = lib.types.str;
      default = "30min";
      description = "How often the user timer checks GitHub (systemd time span).";
    };

    autoUpgrade = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run the full upgrade from the timer instead of only checking.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      [ artcraft-check artcraft-upgrade ]
      ++ lib.concatLists (lib.mapAttrsToList mkApp ready);

    # What is actually activated right now; artcraft-check compares GitHub
    # against this, not against the (possibly already bumped) versions.json.
    xdg.stateFile."artcraft/installed.json".text =
      builtins.toJSON (lib.mapAttrs (_: a: a.version) ready);

    systemd.user.services.artcraft-check = {
      Unit.Description = "Check for ArtCraft updates";
      Service = {
        Type = "oneshot";
        Environment = [ "PATH=${servicePath}" ];
        ExecStart =
          if cfg.autoUpgrade
          then "${artcraft-upgrade}/bin/artcraft-upgrade"
          else "${artcraft-check}/bin/artcraft-check";
      };
    };

    systemd.user.timers.artcraft-check = {
      Unit.Description = "Periodic ArtCraft update check";
      Timer = {
        OnStartupSec = "2min";
        OnUnitActiveSec = cfg.checkInterval;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
