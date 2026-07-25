{ config, pkgs, ... }:

let
  # Absolute path to the quickshell binary (home-manager symlink). The systemd
  # user service does not inherit the interactive shell PATH, so resolve it here.
  qsBin = "/etc/profiles/per-user/${config.home.username}/bin/quickshell";

  # Gate a quickshell service's ExecStart on the Wayland socket existing. The
  # quickshell units are WantedBy=default.target with NO ordering on the
  # compositor — Hyprland runs outside systemd here (no hyprland-session.target,
  # graphical-session.target never activates), so a unit can start BEFORE
  # Hyprland creates wayland-0 → Qt falls back to xcb → "could not connect to
  # display" → FATAL → a 3 s crash-loop (18 core dumps across boots) until the
  # compositor catches up. Blocking ExecStartPre kills that loop at the source:
  # no matter when the unit activates, quickshell only launches once the socket
  # is live. 120×0.5 s = up to 60 s; systemd's default TimeoutStartSec (90 s)
  # covers the wait. If the compositor genuinely never comes up, ExecStartPre
  # exits non-zero → Restart=on-failure retries — no worse than today.
  qsWaitWayland = pkgs.writeShellApplication {
    name = "qs-wait-wayland";
    runtimeInputs = [ pkgs.coreutils ];   # seq, sleep, id
    text = ''
      rt="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      # Gate on the session-declared $WAYLAND_DISPLAY — NEVER hardcode the socket
      # name. This host's compositor creates wayland-1 (not wayland-0); a hardcoded
      # wayland-0 made the gate wait forever and quickshell would never start.
      # `_` (not `i`): writeShellApplication runs shellcheck, which only exempts
      # `_` from its "unused variable" check (SC2034).
      for _ in $(seq 1 120); do
        [ -n "$WAYLAND_DISPLAY" ] && [ -S "$rt/$WAYLAND_DISPLAY" ] && exit 0
        sleep 0.5
      done
      echo "qs-wait-wayland: timed out (WAYLAND_DISPLAY=''${WAYLAND_DISPLAY:-unset}, no socket in $rt)" >&2
      exit 1
    '';
  };

  # A single Quickshell instance bound to a config directory under
  # ~/.config/quickshell. Restart/Install shape mirrors notifications.nix:
  # WantedBy=default.target because graphical-session.target is never activated
  # on this host (verified), so a graphical-session-bound service never starts.
  qsInstance = description: path: {
    Unit = {
      Description = description;
    };
    Service = {
      # Defensive: wait for this service's WAYLAND_DISPLAY socket before launch
      # (see qsWaitWayland). Normally a no-op — the unit is started by
      # environment.lua's hyprland.start hook AFTER `systemctl --user
      # import-environment WAYLAND_DISPLAY`, so $WAYLAND_DISPLAY is set and the
      # socket exists; the gate exits 0 instantly. It only waits if timing lags.
      ExecStartPre = "${qsWaitWayland}/bin/qs-wait-wayland";
      ExecStart = "${qsBin} -c ${config.home.homeDirectory}/.config/quickshell/${path}";
      Restart = "on-failure";
      RestartSec = 3;
    };
    # NO Install/WantedBy on purpose. These units are started EXPLICITLY by
    # environment.lua's hyprland.start hook (configs/hypr/environment.lua), after
    # `systemctl --user import-environment WAYLAND_DISPLAY`. Binding them to
    # default.target ALSO started them — but BEFORE Hyprland imported
    # WAYLAND_DISPLAY → the service had no display → Qt fell back to xcb →
    # "could not connect to display" → FATAL crash-loop (18 core dumps across
    # boots). Dropping WantedBy leaves only the correctly-ordered explicit start.
  };
in
{
  # Elegant native Home Manager abstraction for Quickshell
  programs.quickshell = {
    enable = true;

    # Use the native package property override cleanly
    package = pkgs.quickshell.overrideAttrs (oldAttrs: {
      qtWrapperArgs = (oldAttrs.qtWrapperArgs or []) ++ [
        "--prefix" "QML2_IMPORT_PATH" ":" "${pkgs.kdePackages.qt5compat}/lib/qt-6/qml"
      ];
    });
  };

  # House keeping other companion runtime components
  home.packages = with pkgs; [
    qt6.qt5compat
  ];

  # ── Quickshell instances ─────────────────────────────────────────────────────
  # Run as systemd user services. This replaces the old `systemd.enable = true`,
  # which generated a broken quickshell.service (no -c flag, WantedBy the dead
  # graphical-session.target). environment.lua starts both units deterministically
  # once the session environment has been imported.
  systemd.user.services.quickshell-bar      = qsInstance "Quickshell bar" "bar";
  systemd.user.services.quickshell-settings = qsInstance "Quickshell settings dashboard" "settings";

  # ── Polkit authentication agent ───────────────────────────────────────────────
  # Lives here (not in modules/apps/desktop-apps.nix) because desktop-apps.nix is
  # a NixOS system module with no systemd.user scope. The polkit_gnome PACKAGE is
  # installed system-wide from desktop-apps.nix; this unit launches its agent at
  # session start. Replaces the old `exec_cmd("/usr/lib/polkit-gnome/... &")` in
  # environment.lua, which pointed at a host path that does not exist under NixOS.
  systemd.user.services.polkit-gnome-authentication-agent = {
    Unit = {
      Description = "Polkit-Gnome authentication agent";
    };
    Service = {
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
