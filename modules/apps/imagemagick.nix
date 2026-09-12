# =========================================================================
# IMAGEMAGICK — CLI image toolkit (convert / resize / compose / identify)
# =========================================================================
#
# ImageMagick 7 (IM7). The modern command is `magick` (`magick convert …`,
# `magick identify …`); the old-style bare commands (`convert`, `identify`,
# `mogrify`, …) are still installed as symlinks for compatibility, but IM7
# prints a deprecation warning when they are used.
#
# Delegates (the codecs/formats it can read & write) — this nixpkgs build has
# the full set enabled by default: HEIF/HEIC, JPEG-XL, WebP, AVIF, DJVU,
# OpenJP2, plus the classics (PNG/JPEG/TIFF/GIF). There is no need for the
# `imagemagickBig` variant — it is now just an alias of this package.
#
# Why a system module (and not home-manager): it is a global CLI tool for
# every shell, like the rest of modules/apps/dev-tools.nix. Kept as its own
# file to match the one-module-per-tool pattern (sniffnet.nix, hashcat.nix,
# netwatch.nix). NOTE: nixvim also bundles `imagemagick` as an
# extraPackages entry for snacks.image — that copy only exists inside nvim's
# environment and does NOT put `magick` on your PATH; this module is the
# system-wide source of truth.
#
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    imagemagick
  ];
}
