# =============================================================================
# artcraft.nix — life-cycle wrapper around github:olafkfreund/nix-craftapps
#
# nix-craftapps packages storytold's prebuilt Linux release tarballs of the
# ArtCraft "Craft" apps (PhotoCraft, VectorCraft, PdfCraft, ...) and ships a
# NixOS module (`programs.craftapps`). This file sits on top of it and adds:
#
#   * a simpler option set:  programs.artcraft.apps.<name>.enable
#   * the `artcraft` helper CLI to manage the life-cycle
#   * an optional systemd user timer that notifies you about new upstream commits
#
# -----------------------------------------------------------------------------
# LIFE-CYCLE OVERVIEW
# -----------------------------------------------------------------------------
#   install    apps.<name>.enable = true;           then rebuild
#   list       artcraft list                        installed apps + CLI versions
#   check      artcraft check [--notify]            locked vs upstream revision
#   update     artcraft update                      nix flake update + rebuild
#   hold       just don't run `artcraft update`     flake.lock is the pin
#   rollback   artcraft rollback                    previous NixOS generation
#   remove     apps.<name>.enable = false; rebuild; artcraft gc
#   pin one    programs.craftapps.apps.<name>.package = <older build>;
#              (option provided by nix-craftapps itself)
#
# -----------------------------------------------------------------------------
# SETUP (flakes required)
# -----------------------------------------------------------------------------
# 1. flake.nix — add the input, and pass `inputs` to your modules:
#
#      inputs.nix-craftapps = {
#        url = "github:olafkfreund/nix-craftapps";
#        inputs.nixpkgs.follows = "nixpkgs";
#      };
#
#      outputs = { nixpkgs, ... }@inputs: {
#        nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
#          system = "x86_64-linux";
#          specialArgs = { inherit inputs; };      # <- makes `inputs` available here
#          modules = [ ./configuration.nix ./artcraft.nix ];
#        };
#      };
#
#    NOTE: the input MUST be named `nix-craftapps` (the helper reads that name
#    from flake.lock).
#
# 2. configuration.nix:
#
#      programs.artcraft = {
#        enable = true;
#        flakePath = "/etc/nixos";          # directory with flake.nix + flake.lock
#        # apps.filmcraft.enable = true;    # opt in to more apps
#        # updateCheck.enable = true;       # periodic notification
#      };
#
# 3. sudo nixos-rebuild switch --flake /etc/nixos#<host>
# =============================================================================
{ config, lib, pkgs, inputs, ... }:

let
  inherit (lib) mkOption mkEnableOption mkIf types;

  cfg = config.programs.artcraft;

  # Every app nix-craftapps packages, and whether it is on by default here.
  # The three you asked for default to true; the rest are opt-in.
  appDefaults = {
    photocraft  = true;   # Photoshop-style image editor
    vectorcraft = true;   # Illustrator-style vector illustration
    pdfcraft    = true;   # Acrobat-style PDF workbench
    lightcraft  = false;  # photo library / raw developer
    effectcraft = false;  # motion graphics
    designcraft = false;  # page layout
    filmcraft   = false;  # video editing
    gridcraft   = false;  # spreadsheets
    soundcraft  = false;  # audio workstation
    cadcraft    = false;  # CAD
    wordcraft   = false;  # word processing
    deckcraft   = false;  # presentations
  };

  enabledNames = lib.attrNames (lib.filterAttrs (_: a: a.enable) cfg.apps);

  # ---------------------------------------------------------------------------
  # `artcraft` helper CLI
  # ---------------------------------------------------------------------------
  ctl = pkgs.writeShellApplication {
    name = "artcraft";
    runtimeInputs = with pkgs; [ git jq coreutils libnotify config.nix.package ];
    text = ''
      FLAKE=${lib.escapeShellArg cfg.flakePath}
      HOST=${lib.escapeShellArg cfg.flakeHost}
      INPUT="nix-craftapps"
      UPSTREAM="https://github.com/olafkfreund/nix-craftapps"
      APPS=(${lib.concatStringsSep " " enabledNames})

      die() { echo "artcraft: $*" >&2; exit 1; }

      # Revision of the nix-craftapps input currently locked in flake.lock.
      locked_rev() {
        [ -r "$FLAKE/flake.lock" ] || die "cannot read $FLAKE/flake.lock (set programs.artcraft.flakePath)"
        jq -r --arg i "$INPUT" \
          '.nodes[.nodes.root.inputs[$i]].locked.rev // ""' "$FLAKE/flake.lock"
      }

      cmd_list() {
        local app
        echo "Enabled apps: ''${APPS[*]}"
        for app in "''${APPS[@]}"; do
          printf '%-12s ' "$app"
          "$app-cli" --version 2>/dev/null || echo "(CLI not on PATH yet - rebuild?)"
        done
        echo "nix-craftapps locked at: $(locked_rev | cut -c1-10)"
      }

      cmd_check() {
        local locked latest
        locked=$(locked_rev)
        latest=$(git ls-remote "$UPSTREAM" HEAD | cut -f1)
        [ -n "$latest" ] || die "could not reach $UPSTREAM"
        if [ "$locked" = "$latest" ]; then
          echo "nix-craftapps is up to date (''${latest:0:10})"
        else
          echo "update available: ''${locked:0:10} -> ''${latest:0:10}"
          if [ "''${1:-}" = "--notify" ]; then
            notify-send "ArtCraft" "New nix-craftapps revision available (run: artcraft update)"
          fi
        fi
      }

      # Bump only the nix-craftapps input, then rebuild.
      cmd_update() {
        nix flake update "$INPUT" --flake "$FLAKE"
        echo
        echo "Lock file updated (undo with: git -C $FLAKE checkout flake.lock)"
        sudo nixos-rebuild switch --flake "$FLAKE#$HOST"
      }

      usage() {
        cat <<'EOF'
      artcraft - life-cycle helper for the ArtCraft apps

        artcraft list               enabled apps and their CLI versions
        artcraft check [--notify]   compare locked revision with upstream
        artcraft update             nix flake update nix-craftapps + rebuild
        artcraft rollback           switch to the previous generation
        artcraft gc [args]          nix-collect-garbage (e.g. gc -d)
      EOF
      }

      case "''${1:-help}" in
        list)     cmd_list ;;
        check)    shift; cmd_check "$@" ;;
        update)   cmd_update ;;
        rollback) exec sudo nixos-rebuild switch --rollback ;;
        gc)       shift; exec sudo nix-collect-garbage "$@" ;;
        *)        usage ;;
      esac
    '';
  };
in
{
  # Pull in the NixOS module (programs.craftapps) from the flake input.
  imports = [ inputs.nix-craftapps.nixosModules.default ];

  # ===========================================================================
  # OPTIONS
  # ===========================================================================
  options.programs.artcraft = {
    enable = mkEnableOption "the ArtCraft apps via nix-craftapps";

    flakePath = mkOption {
      type = types.str;
      default = "/etc/nixos";
      example = "/home/nikos/nixos";
      description = ''
        Directory containing your system flake.nix and flake.lock. Used by
        `artcraft check` and `artcraft update`.
      '';
    };

    flakeHost = mkOption {
      type = types.str;
      default = config.networking.hostName;
      defaultText = lib.literalExpression "config.networking.hostName";
      description = "nixosConfigurations attribute rebuilt by `artcraft update`.";
    };

    linkFonts = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Provide /usr/share/fonts. The apps' text tools only look there and do
        not use fontconfig, so leave this on under NixOS.
      '';
    };

    updateCheck = {
      enable = mkEnableOption "a periodic desktop notification when upstream has changed";
      interval = mkOption {
        type = types.str;
        default = "1d";
        description = "How often to check (systemd time span, e.g. \"12h\", \"1d\").";
      };
    };

    apps = lib.mapAttrs
      (name: default: {
        enable = mkOption {
          type = types.bool;
          inherit default;
          description = "Install ${name} (GUI plus ${name}-cli).";
        };
      })
      appDefaults;
  };

  # ===========================================================================
  # CONFIGURATION
  # ===========================================================================
  config = mkIf cfg.enable {

    # Hand the selection over to nix-craftapps' own module.
    programs.craftapps = {
      enable = true;
      linkFonts = cfg.linkFonts;
      apps = lib.mapAttrs (_: a: { enable = a.enable; }) cfg.apps;
    };

    # The apps render on the GPU (wgpu: Vulkan / OpenGL).
    hardware.graphics.enable = lib.mkDefault true;

    # Life-cycle helper.
    environment.systemPackages = [ ctl ];

    # Optional: notify about new upstream revisions (user-level timer).
    systemd.user.services.artcraft-update-check = mkIf cfg.updateCheck.enable {
      description = "Check for new nix-craftapps revisions";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${ctl}/bin/artcraft check --notify";
      };
    };

    systemd.user.timers.artcraft-update-check = mkIf cfg.updateCheck.enable {
      description = "Periodic ArtCraft update check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "10min";
        OnUnitActiveSec = cfg.updateCheck.interval;
      };
    };
  };
}
