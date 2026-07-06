{ config, pkgs, ... }:

{
  # Elegant native Home Manager abstraction for Quickshell
  programs.quickshell = {
    enable = true;
    
    # Use the native package property override cleanly
    package = pkgs.quickshell.overrideAttrs (oldAttrs: {
      qtWrapperArgs = (oldAttrs.qtWrapperArgs or []) ++ [
        "--prefix" "QML2_IMPORT_PATH" ":" "${pkgs.kdePackages.qt5compat}/lib/qt-6/qml"
      ];
    });

    # Automatically handles session target bindings cleanly
    systemd.enable = true;
  };

  # House keeping other companion runtime components
  home.packages = with pkgs; [
    qt6.qt5compat
  ];
}
