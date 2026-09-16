{ config, pkgs, lib, ... }:

{
  services.greetd = {
    enable = true;
    # (do NOT set services.greetd.vt — upstream REMOVED that option; it is a
    # hard eval error in current nixpkgs. TTY handling lives in the
    # serviceConfig block below.)
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --time-format '%I:%M %p | %a %b %d' --remember --asterisks --cmd start-hyprland";
        user = "greeter";
      };
    };
  };

  # Keep the greeter group permissions intact
  users.users.greeter = {
    extraGroups = [ "video" "input" "tty" ];
  };

  # TTY plumbing for the text greeter. NOTE: upstream nixpkgs offers
  # `services.greetd.useTextGreeter = true` which applies this same block PLUS
  # `TTYPath = "/dev/tty1"`; this hand-rolled copy predates it and omits
  # TTYPath. It works today (tuigreet inherits the active VT), but switching
  # to the upstream switch is the cleaner long-term form — revisit together
  # with the `Type = mkForce "simple"` override (upstream default is "idle").
  systemd.services.greetd.serviceConfig = {
    Type = lib.mkForce "simple";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal";
    TTYReset = true;
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };
}
