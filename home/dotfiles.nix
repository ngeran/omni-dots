{ ... }:

let
  # Static hypr source files. Deployed INDIVIDUALLY (not as a whole-dir
  # symlink) so ~/.config/hypr/ stays a REAL, WRITABLE directory — Quickshell
  # writes quickshell-colors.conf into it at runtime (ThemeService), so the dir
  # must never become a read-only store symlink. quickshell-colors.conf is
  # therefore deliberately ABSENT from this list. Edit this list to add/drop a
  # managed file.
  hyprStaticFiles = [
    "hyprland.lua" "monitors.lua" "environment.lua" "look-and-feel.lua"
    "animations.lua" "keybindings.lua" "rules.lua"
    "hypridle.conf" "hyprlock.conf"
  ];
in
{
  # ──────────────────────────────────────────────────────────────────────────
  # Central hub for ingested application configs (the declarative "backup").
  # ──────────────────────────────────────────────────────────────────────────
  # Each entry deploys a checked-in config tree from ../configs/<app> into
  # ~/.config/<app>. To change a config, edit the file under ../configs/<app>/
  # and `omni-apply` — never edit the live ~/.config/<app> directly (store files
  # are read-only).
  #
  # RULE: only STATIC, read-only configs are deployed as whole-dir sources.
  # Apps that WRITE to their config dir at runtime must be deployed PER-FILE so
  # the dir stays writable (see hypr below; the colors.json lesson).
  # ──────────────────────────────────────────────────────────────────────────

  xdg.configFile = {
    # Whole-dir sources — fully static, no runtime writes
    "fastfetch".source    = ../configs/fastfetch;
    "rofi".source         = ../configs/rofi;
    "hypr/scripts".source = ../configs/hypr/scripts;   # scripts/ is static

    # Per-file hypr sources — keeps ~/.config/hypr/ writable for the
    # runtime-written quickshell-colors.conf (see hyprStaticFiles above).
  } // builtins.listToAttrs (builtins.map (f: {
    name        = "hypr/${f}";
    value.source = ../configs/hypr/${f};
  }) hyprStaticFiles);
}
