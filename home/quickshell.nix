{ config, pkgs, ... }:

{
  # ── Quickshell package ───────────────────────────────────────────────────────
  # The PACKAGE only — the quickshell-bar systemd user unit moved to the
  # velocity flake's HM module (P3: the rice ships its own unit, its wayland
  # gate, cliphist, fonts and keybinds; see home/velocity.nix). The stale
  # quickshell-settings unit (second process, deleted in P2) is gone with it.
  # environment.lua's `systemctl --user start quickshell-bar …` line stays:
  # starting an already-active unit is a no-op, and it still covers the
  # rollback path if programs.velocity is ever disabled again.
  programs.quickshell = {
    enable = true;

    # Use the native package property override cleanly
    package = pkgs.quickshell.overrideAttrs (oldAttrs: {
      qtWrapperArgs = (oldAttrs.qtWrapperArgs or []) ++ [
        "--prefix" "QML2_IMPORT_PATH" ":" "${pkgs.kdePackages.qt5compat}/lib/qt-6/qml"
      ];
    });
  };

  # (no qt5compat home.packages entry — the override above already puts
  # kdePackages.qt5compat on QML2_IMPORT_PATH, and qt6.qt5compat resolves to
  # the same store path in current nixpkgs; listing it here suggested a
  # separate package was needed when it isn't.)

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
