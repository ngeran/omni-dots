{ pkgs, ... }:

let
  # ── Doto — variable dot-matrix font (velocity's clock face) ────────────
  # From google/fonts (ofl/doto); carries the ROND (roundness 0–100) and
  # wght axes. velocity's nikos.clock plugin offers it as `clockFace = "dot"`
  # on LARGE clocks only (≥ 26 px: calendar panel hero + lock screen) — the
  # dot grid is illegible below that. ROND 100 gives the full round-dot
  # look; QML applies it via font.variableAxes. Packaged by hand (nixpkgs
  # has no doto); OFL license shipped alongside per its terms.
  doto = pkgs.runCommand "doto-font" { } ''
    mkdir -p $out/share/fonts/truetype $out/share/licenses/doto
    cp ${pkgs.fetchurl {
      name = "Doto-var.ttf";
      url = "https://github.com/google/fonts/raw/main/ofl/doto/Doto%5BROND%2Cwght%5D.ttf";
      hash = "sha256-b0/n03hTuR3zaY2qhM3i2+HJaV2IyYbmUQE0kQM31CY=";
    }} "$out/share/fonts/truetype/Doto[ROND,wght].ttf"
    cp ${pkgs.fetchurl {
      name = "Doto-OFL.txt";
      url = "https://github.com/google/fonts/raw/main/ofl/doto/OFL.txt";
      hash = "sha256-Jqe1i9umzainjKbos3kdgBO4q8bV5lGfhBk4k67gICA=";
    }} $out/share/licenses/doto/OFL.txt
  '';
in
{
  fonts = {
    # Allows applications to find fonts installed via Nix
    enableDefaultPackages = true;
    
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      noto-fonts
      # (noto-fonts-color-emoji deliberately NOT listed — it is part of the
      # enableDefaultPackages set above; listing it again just duplicated it.)

      # ── DaVinci Resolve UI fonts ───────────────────────────────────────
      # DaVinci's Qt UI requests Arial/Verdana/Helvetica (Microsoft core
      # fonts); without them it falls back to an ugly default → "horrible"
      # UI text. corefonts is unfree (allowed via core/default.nix → allowUnfree).
      #
      # NOTE: dejavu_fonts and liberation_ttf used to be listed here as the
      # Arial/Times fallback + broad coverage — but `enableDefaultPackages =
      # true` above ALREADY ships both (plus freefont, gyre, unifont and
      # Noto CJK — see nixpkgs nixos/modules/config/fonts/packages.nix).
      # Listing them again just duplicated packages in the closure.
      corefonts

      # velocity dot-matrix clock face (see `doto` above)
      doto
    ];

    # Optional: Set default fonts for the system
    fontconfig = {
      defaultFonts = {
        monospace = [ "JetBrainsMono Nerd Font" ];
        sansSerif = [ "Noto Sans" ];
        serif     = [ "Noto Serif" ];
      };
      # Explicit rendering tuning — ensures DaVinci's Qt gets clean
      # antialiased, hinted, subpixel-rendered text (these match the NixOS
      # defaults; made explicit so a fontconfig regression can't silently
      # degrade them).
      antialias = true;
      hinting.enable = true;
      subpixel.rgba = "rgb";
    };
  };
}
