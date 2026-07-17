{ pkgs, ... }:

{
  fonts = {
    # Allows applications to find fonts installed via Nix
    enableDefaultPackages = true;
    
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      noto-fonts
      noto-fonts-color-emoji # <-- Renamed from noto-fonts-emoji

      # ── DaVinci Resolve UI fonts ───────────────────────────────────────
      # DaVinci's Qt UI requests Arial/Verdana/Helvetica (Microsoft core
      # fonts); without them it falls back to an ugly default → "horrible"
      # UI text. corefonts is unfree (allowed via core/default.nix → allowUnfree).
      corefonts
      liberation_ttf   # free, metric-compatible Arial/Times/Courier fallback
      dejavu_fonts     # broad sans/serif/mono coverage
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
