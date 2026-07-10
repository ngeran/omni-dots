# Home Manager configuration for dell4400
# Minimal setup: Hyprland + CLI tools
# NixOS 26.05

{ config, pkgs, inputs, ... }:

{
  # ===== BASIC INFO =====
  home.username = "nikos";
  home.homeDirectory = "/home/nikos";

  # ===== IMPORTS =====
  imports = [
   # ./features/desktop/hyprland
    #./features/desktop/hyprland/monitors.nix
  ];


  # ===== HOME PACKAGES =====
  home.packages = with pkgs; [
    git
    curl
    wget
    tree
    # Terminals
    alacritty
    kitty
    # Browser 
    chromium
    #===MISC===
    qt6.qt5compat
    swww
    hyprlock
    hypridle
    # ====================
    # 2. Add the wrapped quickshell package right at the bottom of the same list:
    (pkgs.quickshell.overrideAttrs (oldAttrs: {
      qtWrapperArgs = (oldAttrs.qtWrapperArgs or []) ++ [
        "--prefix" "QML2_IMPORT_PATH" ":" "${pkgs.kdePackages.qt5compat}/lib/qt-6/qml"
      ];
    }))
    
  ];



  # ===== PROGRAMS =====
  programs.home-manager.enable = true;
  programs.bash.enable = true;

  # ===== SESSION VARIABLES =====
  home.sessionVariables = {
    EDITOR = "vim";
  };

  # ===== STATE VERSION =====
  # Read the changelog before changing this
  home.stateVersion = "26.05";
}
