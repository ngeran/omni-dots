# =========================================================================
# Creative apps — DaVinci Resolve + Blender  (home / user layer)
# =========================================================================
{ pkgs, ... }:

let
  # Custom wrapper for DaVinci on the 4K OLED.
  #
  # Scaling strategy (Hyprland scale = 1.5, xwayland.force_zero_scaling = true):
  #   - force_zero_scaling gives Resolve the full 3840x2160 XWayland canvas (no
  #     compositor upscale => sharp), so the app must scale itself.
  #   - Set the 1.5 factor HERE at the Qt level (Resolve bundles Qt 5.15.2,
  #     which rasterizes fonts at fractional DPR). This is also what unlocks
  #     Resolve's own Preferences → User → UI Settings → "UI Display Scale"
  #     dropdown — it stays locked at 100% when the screen is detected as
  #     standard-DPI (Qt DPR = 1.0).
  #   - Do NOT add QT_FONT_DPI / Xft.dpi on top of a UI scale — that was the
  #     old workaround and double-scales fonts (soft text) at any factor > 1.
  davinci-wrapped = pkgs.symlinkJoin {
    name = "davinci-resolve-wrapped";
    paths = [ pkgs.davinci-resolve ];
    nativeBuildInputs = [ pkgs.makeWrapper ];

    postBuild = ''
      # Remove the read-only binary symlink so we can replace it with our script
      rm $out/bin/davinci-resolve

      # Single scaler = Qt fractional DPR 1.5; AUTO off keeps XWayland's fake
      # physical size (96 DPI under force_zero_scaling) from overriding it.
      makeWrapper ${pkgs.davinci-resolve}/bin/davinci-resolve $out/bin/davinci-resolve \
        --set QT_QPA_PLATFORM xcb \
        --set QT_AUTO_SCREEN_SCALE_FACTOR 0 \
        --set QT_SCREEN_SCALE_FACTORS "1.5"

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
