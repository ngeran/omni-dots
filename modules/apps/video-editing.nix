# =========================================================================
# Creative apps — DaVinci Resolve + Blender  (home / user layer)
# =========================================================================
{ pkgs, ... }:

let
  # Create a custom wrapper for DaVinci to fix fuzzy scaling on 4K OLED.
  davinci-wrapped = pkgs.symlinkJoin {
    name = "davinci-resolve-wrapped";
    paths = [ pkgs.davinci-resolve ];
    nativeBuildInputs = [ pkgs.makeWrapper pkgs.xrdb ];
    
    postBuild = ''
      # Remove the read-only binary symlink so we can replace it with our wrapper script
      rm $out/bin/davinci-resolve

      # Generate the wrapper with integer scaling variables for pixel-perfect font rendering
      makeWrapper ${pkgs.davinci-resolve}/bin/davinci-resolve $out/bin/davinci-resolve \
        --set QT_QPA_PLATFORM xcb \
        --set QT_AUTO_SCREEN_SCALE_FACTOR 0 \
        --set QT_SCREEN_SCALE_FACTORS "2.0" \
        --set QT_FONT_DPI 144 \
        --run "${pkgs.xrdb}/bin/xrdb -merge <<EOF
Xft.dpi: 144
EOF"

      # Safely handle the desktop file by making a local writeable copy
      if [ -f ${pkgs.davinci-resolve}/share/applications/davinci-resolve.desktop ]; then
        rm -f $out/share/applications/davinci-resolve.desktop
        cp ${pkgs.davinci-resolve}/share/applications/davinci-resolve.desktop $out/share/applications/davinci-resolve.desktop
        chmod +w $out/share/applications/davinci-resolve.desktop
        
        # Force the Exec line to point directly to our custom wrapped binary
        sed -i 's|^Exec=.*|Exec='"$out"'/bin/davinci-resolve %u|' $out/share/applications/davinci-resolve.desktop
      fi
    '';
  };
in
{
  home.packages = [
    davinci-wrapped    # Scaled and sharp version
    pkgs.blender       # Native Wayland
  ];
}
