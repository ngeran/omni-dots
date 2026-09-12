# =========================================================================
# GHOSTSCRIPT — PostScript/PDF interpreter (gs, ps2pdf, pdf2ps, …)
# =========================================================================
#
# Ghostscript 10.x (mainline — the AGPL release nixpkgs ships). Provides the
# `gs` interpreter plus the conversion scripts: ps2pdf, pdf2ps, ps2eps,
# eps2eps, pdfdsc, …
#
# Synergy with modules/apps/imagemagick.nix: ImageMagick resolves its
# PostScript/EPS/PDF delegate (`gs`) at RUNTIME from PATH, so with this
# module installed `magick` can rasterize PS/EPS/PDF inputs that it
# otherwise refuses ("no decode delegate"). One source of truth per
# package, two cooperating modules.
#
# Why a system module: global CLI tool for every shell — same reasoning as
# imagemagick.nix and the other one-module-per-tool files in modules/apps/.
#
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    ghostscript
  ];
}
