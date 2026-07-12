# =========================================================================
# MATUGEN — runtime wallpaper → Material-You color palette
# =========================================================================
# Hybrid theme architecture (see also modules/stylix.nix + home/stylix.nix):
#
#   • Stylix  = the COLD-BOOT seed. At build time it generates a base16
#               palette from wallpaper.jpg and bridges it into
#               ~/.config/quickshell/stylix-palette.json (read-only). Quickshell
#               loads it once on first boot / when no live theme is chosen.
#
#   • matugen = the RUNTIME generator. Quickshell runs `matugen image <live
#               wallpaper> --json hex` on demand and writes the result to the
#               LIVE channel (~/.cache/theme/colors.json) — NO rebuild. This is
#               what makes "custom palette from the active wallpaper" instant.
#
# Stylix stays (palette-only, autoEnable=false); matugen does not replace it,
# it complements it for live wallpaper changes. The two never fight: once a
# matugen (or preset/custom/manual) theme is active, Quickshell's clobber-guard
# (ThemeService.qml loadStylixSeed) skips the Stylix seed on later boots.
#
# Why a flake input and not pkgs.matugen: nixpkgs matugen 4.0.0's `image`
# subcommand is broken (cannot decode images). github:InioX/matugen works.
# =========================================================================
{ inputs, pkgs, ... }:

{
  # NOTE: use pkgs.stdenv.hostPlatform.system, not the deprecated pkgs.system
  # (which emits the "'system' has been renamed to stdenv.hostPlatform.system"
  # evaluation warning).
  environment.systemPackages = [
    inputs.matugen.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
