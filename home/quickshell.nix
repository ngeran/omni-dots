{ config, pkgs, ... }:

let
  # Absolute path to the quickshell binary (home-manager symlink). The systemd
  # user service does not inherit the interactive shell PATH, so resolve it here.
  qsBin = "/etc/profiles/per-user/${config.home.username}/bin/quickshell";

  # A single Quickshell instance bound to a config directory under
  # ~/.config/quickshell. Restart/Install shape mirrors notifications.nix:
  # WantedBy=default.target because graphical-session.target is never activated
  # on this host (verified), so a graphical-session-bound service never starts.
  qsInstance = description: path: {
    Unit = {
      Description = description;
    };
    Service = {
      ExecStart = "${qsBin} -c ${config.home.homeDirectory}/.config/quickshell/${path}";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
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
