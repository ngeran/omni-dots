# =========================================================================
# Creative apps — DaVinci Resolve + Blender  (home / user layer)
# =========================================================================
{ pkgs, inputs, ... }:

let
  # ---------------------------------------------------------------------
  # Resolve comes from a DEDICATED exact-rev pin (nixpkgs-davinci in
  # flake.nix), NOT from the shared nixpkgs-unstable lock — bumping that
  # one would drag matugen/opencode along. The pinned rev is upstream's
  # "davinci-resolve: 21.1 -> 21.1.1" commit, which already carries the
  # re-pinned source hash (Blackmagic rotated the 21.1 zip on S3 and
  # upstream re-hashed it on 2026-09-11) — so the old local `davinci-hash-fix`
  # overlay that worked around the stale hash is GONE. Do not resurrect it:
  # it would override the 21.1.1 zip's hash with the old 21.1 one and break
  # the build.
  #
  # To bump Resolve: find the rev of upstream's next version-bump commit at
  #   https://github.com/NixOS/nixpkgs/commits/nixos-unstable/pkgs/by-name/da/davinci-resolve/package.nix
  # and move the nixpkgs-davinci pin in flake.nix to it.
  # ---------------------------------------------------------------------
  pkgs-davinci = import inputs.nixpkgs-davinci {
    system = pkgs.system;
    config.allowUnfree = true; # davinci-resolve is unfree (binary distribution)
  };

  davinci-pkg = pkgs-davinci.davinci-resolve;

  # Re-wrap the FHS package: Resolve's bundled Qt misbehaves under Hyprland's
  # mixed-DPI setup, so force xcb (not wayland) and a fixed 1.5 scale factor.
  davinci-wrapped = pkgs.symlinkJoin {
    name = "davinci-resolve-wrapped";
    paths = [ davinci-pkg ];
    nativeBuildInputs = [ pkgs.makeWrapper ];

    postBuild = ''
      # Remove the read-only binary symlink
      rm $out/bin/davinci-resolve

      # ...and replace it with a wrapper setting the Qt env
      makeWrapper ${davinci-pkg}/bin/davinci-resolve $out/bin/davinci-resolve \
        --set QT_QPA_PLATFORM xcb \
        --set QT_AUTO_SCREEN_SCALE_FACTOR 0 \
        --set QT_SCREEN_SCALE_FACTORS "1.5"

      if [ -f ${davinci-pkg}/share/applications/davinci-resolve.desktop ]; then
        rm -f $out/share/applications/davinci-resolve.desktop
        cp ${davinci-pkg}/share/applications/davinci-resolve.desktop $out/share/applications/davinci-resolve.desktop
        chmod +w $out/share/applications/davinci-resolve.desktop

        sed -i 's|^Exec=.*|Exec='"$out"'/bin/davinci-resolve %u|' $out/share/applications/davinci-resolve.desktop
      fi
    '';
  };
in
{
  home.packages = [
    davinci-wrapped
    pkgs.blender       # This remains on your standard 26.05 branch
  ];
}
