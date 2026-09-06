# =========================================================================
# Creative apps — DaVinci Resolve + Blender  (home / user layer)
# =========================================================================
{ pkgs, inputs, ... }: # 1. Add 'inputs' to the arguments

let
  # 2. Create a reference to the unstable package set for your specific system
  pkgs-unstable = import inputs.nixpkgs-unstable {
    system = pkgs.system;
    config.allowUnfree = true;
  };

  # 3. Reference the package from unstable instead of stable
  davinci-pkg = pkgs-unstable.davinci-resolve;

  davinci-wrapped = pkgs.symlinkJoin {
    name = "davinci-resolve-wrapped";
    paths = [ davinci-pkg ]; # Use our new variable
    nativeBuildInputs = [ pkgs.makeWrapper ];

    postBuild = ''
      # Remove the read-only binary symlink
      rm $out/bin/davinci-resolve

      # Use the variable in the wrapper path
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
