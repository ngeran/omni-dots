# =========================================================================
# Creative apps — DaVinci Resolve + Blender  (home / user layer)
# =========================================================================
{ pkgs, inputs, ... }: # 1. Add 'inputs' to the arguments

let
  # ---------------------------------------------------------------------
  # LOCAL HASH FIX (2026-09-12) — REMOVE WHEN UPSTREAM RE-PINS THE HASH
  # ---------------------------------------------------------------------
  # Blackmagic re-released Resolve 21.1 server-side (S3 path moved to
  # "v21.1-1"), so the zip bytes changed and the hash pinned in the
  # unstable expression (from 2026-09-09) went stale — every build dies
  # with "hash mismatch in fixed-output derivation davinci-resolve-src.zip".
  # KNOWN RECURRING failure mode for this package (see nixpkgs issue
  # #422461 for the 21.0-era occurrence). Both post-rotation downloads
  # hashed the same (sha256-+3SB32E…), so the new artifact is stable.
  #
  # Why an overlay that patches `runCommandLocal`: the source hash is
  # INLINE inside package.nix's inner `davinci` derivation, and the final
  # package is `buildFHSEnv` wrapping that inner derivation — an
  # `.overrideAttrs` on the outside cannot reach it (the wrapper keeps
  # depending on the original). Patching the fetcher call IS the
  # interception point the inner derivation uses.
  #
  # To check whether upstream has re-pinned:
  #   https://github.com/NixOS/nixpkgs/commits/nixos-unstable/pkgs/by-name/da/davinci-resolve/package.nix
  # Any commit newer than 2026-09-09 touching that file → delete this
  # overlay and pass NO overlays to the import below.
  # ---------------------------------------------------------------------
  davinci-hash-fix = _final: prev: {
    runCommandLocal = name: attrs: body:
      if name == "davinci-resolve-src.zip" then
        prev.runCommandLocal name
          (attrs // {
            # was sha256-bQ4Yag4xfIF9Fs0UVKaYFhObMsAof5n+Sy4osw35a9g= upstream
            outputHash = "sha256-+3SB32EHpH9/0hM3h8CrO6f7V4ZAmxUFh3P8m6QDeO0=";
          })
          body
      else prev.runCommandLocal name attrs body;
  };

  # 2. Create a reference to the unstable package set for your specific system
  pkgs-unstable = import inputs.nixpkgs-unstable {
    system = pkgs.system;
    config.allowUnfree = true;
    overlays = [ davinci-hash-fix ];
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
