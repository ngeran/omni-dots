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
    # Whole-dir sources — fully static, no runtime writes.
    # NOTE: ghostty is deliberately NOT here — Quickshell writes the live
    # theme into ~/.config/ghostty/config at runtime, so that file must stay
    # writable (a whole-dir symlink would make it read-only and silently break
    # live theming — the colors.json lesson). See ThemeService.syncToExternalApps.
    "fastfetch".source    = ../configs/fastfetch;
    "rofi".source         = ../configs/rofi;
    # tmux: whole-dir is safe — tmux never writes to its config dir (the LIVE
    # theme file it sources lives in ~/.cache/theme/tmux.conf, written by
    # Quickshell's ThemeService._syncTmux — see configs/tmux/tmux.conf header).
    "tmux".source         = ../configs/tmux;
    "hypr/scripts".source = ../configs/hypr/scripts;   # scripts/ is static

    # kitty + ngeran are deliberately NOT here (removed 2026-09-15):
    #   • kitty — the package is uninstalled (ghostty is the terminal); its
    #     whole-dir deployment was dead weight.
    #   • ngeran — this dir is RUNTIME-OWNED by Quickshell (velocity): the
    #     settings Header reads ~/.config/ngeran/identity/{avatar.png,
    #     identity.txt} and ManualThemeEditor targets a theme file here. The
    #     old whole-dir symlink made it read-only, so those writes/reads
    #     silently failed (same class as the colors.json lesson) — the only
    #     thing it actually contained was a kitty theme nobody read. The dir
    #     must stay unmanaged so velocity can create/write it.

    # Per-file hypr sources — keeps ~/.config/hypr/ writable for the
    # runtime-written quickshell-colors.conf (see hyprStaticFiles above).
  } // builtins.listToAttrs (builtins.map (f: {
    name        = "hypr/${f}";
    value.source = ../configs/hypr/${f};
  }) hyprStaticFiles);
}
