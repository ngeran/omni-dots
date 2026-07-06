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
    ];

    # Optional: Set default fonts for the system
    fontconfig = {
      defaultFonts = {
        monospace = [ "JetBrainsMono Nerd Font" ];
        sansSerif = [ "Noto Sans" ];
        serif     = [ "Noto Serif" ];
      };
    };
  };
}
