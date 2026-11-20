# TigerVNC viewer for the velocity bar's nikos.vnc plugin.
#
# What this gives the desktop:
#   - `vncviewer` on the system PATH for ad-hoc terminal use AND for the bar
#     plugin's connect action (also added to the bar unit's runtimeInputs in
#     the velocity flake — this module is the system-level half).
#   - `vncpasswd`: the one-time generator for the VNC password file the
#     viewer loads via -PasswordFile. The password itself lives in
#     ~/.config/secrets/ (repo secrets policy) — only its PATH ever reaches
#     QML, never the secret.
#
# The plugin needs no daemon: vncviewer is a plain client process launched
# detached (ctx.run) and torn down with `pkill -x vncviewer`. Reachability
# probes use `ping`/`nc`, which come from the bar's runtimeInputs.
{ config, lib, pkgs, ... }:

let
  cfg = config.services.velocityVnc;
in
{
  options.services.velocityVnc = {
    enable = lib.mkEnableOption "TigerVNC viewer for the velocity bar";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.tigervnc ];
  };
}
