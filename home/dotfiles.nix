{ ... }:

{
  # ──────────────────────────────────────────────────────────────────────────
  # Central hub for ingested application configs (the declarative "backup").
  # ──────────────────────────────────────────────────────────────────────────
  # Each entry deploys a checked-in config tree from ../configs/<app> into
  # ~/.config/<app> as a read-only Nix-store symlink. To change a config, edit
  # the file under ../configs/<app>/ and `omni-apply` — never edit the live
  # ~/.config/<app> directly (it's a symlink into the store).
  #
  # RULE: only STATIC, read-only configs go here. Apps that WRITE to their
  # config dir at runtime must NOT be sourced wholesale — the store symlink is
  # immutable and the write would silently fail (the colors.json lesson).
  # Example: Quickshell writes ~/.config/hypr/quickshell-colors.conf at runtime,
  # so hypr/ cannot be sourced as a whole — only its static files can.
  # ──────────────────────────────────────────────────────────────────────────

  xdg.configFile."fastfetch".source = ../configs/fastfetch;
  xdg.configFile."rofi".source      = ../configs/rofi;
}
