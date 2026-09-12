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
# Why from UNSTABLE (2026-09-12, was github:InioX/matugen): the channel's
# matugen is still 4.0.0 with the broken `image` subcommand, but
# nixpkgs-unstable ships 4.2.0 where it works — binary-cached on
# cache.nixos.org, so no local Rust build. Same package the upstream flake
# was fetching, minus a whole flake input and its crate-vendoring. If
# unstable's version ever regresses, the old input was
# `github:InioX/matugen` (pattern: modules/apps/video-editing.nix).
# =========================================================================
{ inputs, pkgs, ... }:

let
  # Same unstable-package pattern as modules/apps/video-editing.nix.
  # NOTE: stdenv.hostPlatform.system, not the deprecated pkgs.system.
  pkgs-unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in

{
  environment.systemPackages = [
    pkgs-unstable.matugen
  ];
}
