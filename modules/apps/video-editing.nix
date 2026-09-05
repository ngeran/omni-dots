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
  #   - Pin Qt to a deterministic 1.0 base here, then let Resolve's BUILT-IN
  #     scaler do the real work: Preferences → User → UI Settings →
  #     "UI Display Scale" (native since Resolve 18.1). Set it to 150%.
  #   - Do NOT set QT_FONT_DPI / Xft.dpi alongside it — that was the pre-18.1
  #     workaround and double-scales fonts (soft text) when a UI scale is active.
  davinci-wrapped = pkgs.symlinkJoin {
    name = "davinci-resolve-wrapped";
    paths = [ pkgs.davinci-resolve ];
    nativeBuildInputs = [ pkgs.makeWrapper ];

    postBuild = ''
      # Remove the read-only binary symlink so we can replace it with our wrapper script
      rm $out/bin/davinci-resolve

      # Clean, pinned 1.0 Qt base; the only scaler on top is Resolve's own
      # "UI Display Scale" preference (kept as the single source of truth so
      # Qt auto-detection can never double-multiply it).
      makeWrapper ${pkgs.davinci-resolve}/bin/davinci-resolve $out/bin/davinci-resolve \
        --set QT_QPA_PLATFORM xcb \
        --set QT_AUTO_SCREEN_SCALE_FACTOR 0 \
        --set QT_SCREEN_SCALE_FACTORS "1.0"

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
