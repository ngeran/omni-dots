# =========================================================================
# Creative apps — DaVinci Resolve + Blender  (home / user layer)
# =========================================================================
{ pkgs, ... }:

let
  # Create a custom wrapper for DaVinci to fix fuzzy scaling on 4K OLED.
  # We use xrdb to force the DPI, which unlocks the internal scaling engine.
  davinci-wrapped = pkgs.symlinkJoin {
    name = "davinci-resolve-wrapped";
    paths = [ pkgs.davinci-resolve ];
    nativeBuildInputs = [ pkgs.makeWrapper pkgs.xrdb ];
    postBuild = ''
      wrapProgram $out/bin/davinci-resolve \
        --set QT_QPA_PLATFORM xcb \
        --set QT_AUTO_SCREEN_SCALE_FACTOR 0 \
        --set QT_SCALE_FACTOR 1.5 \
        --run "${pkgs.xrdb}/bin/xrdb -merge <<EOF
Xft.dpi: 144
EOF"
    '';
  };
in
{
  home.packages = with pkgs; [
    davinci-wrapped    # Scaled and sharp version
    blender           # Native Wayland
  ];
}
