{ config, pkgs, lib, ... }:

{
  services.greetd = {
    enable = true;
    # REMOVED: vt = 1; <-- Delete this line completely
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
