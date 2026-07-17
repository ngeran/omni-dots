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
      # Remove the read-only symlink so we can replace it with a wrapper script
      rm $out/bin/davinci-resolve

      # Generate the wrapper pointing directly back to the actual package binary
      makeWrapper ${pkgs.davinci-resolve}/bin/davinci-resolve $out/bin/davinci-resolve \
        --set QT_QPA_PLATFORM xcb \
        --set QT_AUTO_SCREEN_SCALE_FACTOR 0 \
        --set QT_SCALE_FACTOR 1.5 \
        --run "${pkgs.xrdb}/bin/xrdb -merge <<EOF
Xft.dpi: 144
EOF"

      # Patch the desktop launcher entry so GUI menus actually execute our wrapper
      if [ -f $out/share/applications/davinci-resolve.desktop ]; then
        substituteInPlace $out/share/applications/davinci-resolve.desktop \
          --replace-fail "${pkgs.davinci-resolve}/bin/davinci-resolve" "$out/bin/davinci-resolve"
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
