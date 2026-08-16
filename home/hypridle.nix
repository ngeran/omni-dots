# =============================================================================
# hypridle.nix — the idle daemon as a supervised systemd user service
# =============================================================================
# WHAT THIS REPLACES (previously started from configs/hypr/environment.lua):
#     sleep 2 && cp -n <ingested conf> ~/.cache/hypr/... && hypridle ... &
#
# Three problems with that old line:
#   1. No supervision — if hypridle ever crashed, NOTHING restarted it, so
#      screen-lock / suspend timers silently stopped working.
#   2. Duplicate instances — the `&` process survived Hyprland restarts, so a
#      second hypridle was spawned next to the old one on every restart.
#   3. Stale config — `cp -n` never overwrites an existing file, so after the
#      FIRST copy, every edit to configs/hypr/hypridle.conf was invisible to
#      the running daemon. (The ingested config is a plain read-only symlink;
#      hypridle can read it directly — the cache copy was never needed.)
#
# The unit mirrors the Quickshell instances in home/quickshell.nix: it is
# started EXPLICITLY by environment.lua's hyprland.start hook (after the
# session environment has been imported into the systemd user manager) and has
# NO Install section on purpose — on this host graphical-session.target is
# never activated (Hyprland runs outside systemd), so binding to it would mean
# the service never starts.
# =============================================================================
{ config, pkgs, ... }:

let
  # Absolute path to the hypridle binary (home-manager profile symlink). A
  # systemd user service does NOT inherit the interactive shell's PATH, so the
  # path must be resolved here (same pattern as qsBin in quickshell.nix).
  hypridleBin = "/etc/profiles/per-user/${config.home.username}/bin/hypridle";

  # Defensive gate: block until the compositor's Wayland socket exists (same
  # pattern as qs-wait-wayland in home/quickshell.nix). hypridle talks the
  # ext-idle-notify Wayland protocol, so without a display it would die — and
  # with Restart=on-failure it would crash-loop until the socket appears.
  # 120 × 0.5 s = up to 60 s of waiting; normally it exits instantly because
  # environment.lua starts the unit only after the socket is live.
  hypridleWaitWayland = pkgs.writeShellApplication {
    name = "hypridle-wait-wayland";
    runtimeInputs = [ pkgs.coreutils ];   # seq, sleep, id
    text = ''
      rt="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      # Gate on the session-declared $WAYLAND_DISPLAY — NEVER hardcode the
      # socket name (this compositor creates wayland-1, not wayland-0).
      # `_` (not `i`): writeShellApplication runs shellcheck, which only
      # exempts `_` from its "unused variable" check (SC2034).
      for _ in $(seq 1 120); do
        [ -n "$WAYLAND_DISPLAY" ] && [ -S "$rt/$WAYLAND_DISPLAY" ] && exit 0
        sleep 0.5
      done
      echo "hypridle-wait-wayland: timed out (WAYLAND_DISPLAY=''${WAYLAND_DISPLAY:-unset}, no socket in $rt)" >&2
      exit 1
    '';
  };
in
{
  # The hypridle PACKAGE lives here now (moved out of
  # modules/apps/desktop-apps.nix) so this module owns it end-to-end —
  # package + unit — exactly like home/quickshell.nix owns quickshell.
  home.packages = [ pkgs.hypridle ];

  systemd.user.services.hypridle = {
    Unit = {
      Description = "Hyprland idle daemon (screen lock / suspend timers)";
    };
    Service = {
      ExecStartPre = "${hypridleWaitWayland}/bin/hypridle-wait-wayland";
      # Point straight at the INGESTED config — home/dotfiles.nix deploys it
      # as a read-only symlink into the Nix store, which hypridle can read
      # fine. No ~/.cache copy, so config edits always take effect on restart.
      # Logs go to the journal: `journalctl --user -u hypridle -f`
      # (the old ~/.local/state/hypr/hypridle.log redirect is gone).
      ExecStart = "${hypridleBin} -c ${config.home.homeDirectory}/.config/hypr/hypridle.conf";
      Restart = "on-failure";
      RestartSec = 3;
    };
    # NO Install/WantedBy — see the file header. environment.lua runs
    # `systemctl --user start hypridle` once per Hyprland start; starting an
    # already-active unit is a no-op, which also kills the duplicate-instance
    # bug for free.
  };
}
