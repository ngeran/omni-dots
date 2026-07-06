{ config, ... }:

let
  # config.lib.stylix.colors is populated by Stylix from `stylix.image`.
  # `.withHashtag` yields "#rrggbb" strings keyed by base00..base0F.
  c = config.lib.stylix.colors.withHashtag;
in
{
  # =========================================================================
  # Stylix -> Quickshell palette seed (read-only)
  # =========================================================================
  # Maps Stylix's base16 palette into Quickshell's 16-token schema. Quickshell's
  # ThemeService.loadStylixSeed() reads this and applies it, writing the LIVE copy
  # to ~/.cache/theme/colors.json (which the bar watches via FileView). This file
  # is regenerated on every rebuild from the current wallpaper.
  #
  # It is intentionally a home-manager `home.file` (read-only nix-store symlink):
  # a SEED, not the live theme. The live theme (colors.json) stays writable so
  # presets / manual edits can override it at runtime.
  #
  # base16 -> Quickshell token mapping (base16 semantic roles):
  #   base00 darkest bg      -> background
  #   base01 light bg        -> surface / surfaceContainer / border / outlineVariant
  #   base02 selection bg    -> surfaceVariant / outline
  #   base03 comments        -> textDim
  #   base05 default fg      -> text
  #   base0D blue            -> primary
  #   base0C cyan            -> secondary / info
  #   base0E magenta         -> accent
  #   base0B green           -> success
  #   base0A yellow          -> warning
  #   base08 red             -> error
  # =========================================================================
  home.file.".config/quickshell/stylix-palette.json".text = builtins.toJSON {
    colors = {
      background       = c.base00;
      surface          = c.base01;
      surfaceVariant   = c.base02;
      surfaceContainer = c.base01;
      text             = c.base05;
      textDim          = c.base03;
      border           = c.base01;
      outline          = c.base02;
      outlineVariant   = c.base01;
      primary          = c.base0D;
      secondary        = c.base0C;
      accent           = c.base0E;
      success          = c.base0B;
      warning          = c.base0A;
      error            = c.base08;
      info             = c.base0C;
    };
    metadata = {
      name = "Stylix";
      source = "stylix";
      applied = "";
      oledClamp = false;
    };
  };
}
