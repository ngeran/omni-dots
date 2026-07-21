{ config, pkgs, ... }:

let
  # qs-apply-wallpaper — the dashboard (ThemeService) runs
  # `pkexec qs-apply-wallpaper <image>`; this script copies the image into the
  # flake tree as wallpaper.jpg, then rebuilds so Stylix regenerates the palette
  # seed. Paths are derived from config (not hardcoded) so the same module works
  # on every host. pkexec runs it as root, where $HOME is /root — hence the
  # absolute, config-derived paths.
  user     = "nikos";
  home     = config.users.users.${user}.home;     # /home/nikos
  flakeDir = "${home}/.omni-nix";
  host     = config.networking.hostName;          # nixos-btw | dell3440

  qsApplyWallpaper = pkgs.writeShellScriptBin "qs-apply-wallpaper" ''
    set -euo pipefail
    SRC="''${1:?usage: qs-apply-wallpaper <image-path>}"
    [ -f "$SRC" ] || { echo "not a file: $SRC" >&2; exit 1; }
    cp -f -- "$SRC" "${flakeDir}/wallpaper.jpg"
    chown ${user}:users "${flakeDir}/wallpaper.jpg" 2>/dev/null || true
    exec nixos-rebuild switch --flake "${flakeDir}#${host}"
  '';

  # The EXACT store path polkit sees: it resolves the /run/current-system/sw/bin
  # symlink the dashboard pkexecs down to this store path. Matching the exact
  # path — not a substring — closes the bypass where any binary with
  # "qs-apply-wallpaper" in its path could get passwordless root. Interpolated at
  # build time so it tracks the per-rebuild store hash automatically.
  qsApplyWallpaperBin = "${qsApplyWallpaper}/bin/qs-apply-wallpaper";
in {
  # =========================================================================
  # Stylix — cold-boot palette SEED (hybrid with matugen runtime)
  # =========================================================================
  # HYBRID ARCHITECTURE:
  #   • Stylix (HERE) generates a base16 palette from wallpaper.jpg at BUILD
  #     time and bridges it into the Quickshell seed (home/stylix.nix). It is
  #     the COLD-BOOT seed only — loaded once when no live theme is active.
  #   • matugen (modules/matugen.nix, from github:InioX/matugen) is the RUNTIME
  #     generator: Quickshell runs it on the LIVE wallpaper for instant palettes
  #     with NO rebuild. This is what makes wallpaper→palette instant.
  #   They never fight: Quickshell's clobber-guard (loadStylixSeed) skips the
  #   seed once a non-stylix theme is active.
  #
  # NOTE: nixpkgs matugen 4.0.0's `image` subcommand is broken (cannot decode
  # images) — that is why matugen comes from a flake input, not pkgs.matugen.
  #
  # SCOPE: palette generator ONLY. `autoEnable = false` disables all of Stylix's
  # per-app targets so it does NOT fight Quickshell's ThemeService.syncToExternalApps
  # (which themes ghostty/kitty/hyprlock/nvim/rofi/gtk live). The palette is
  # exposed as `config.lib.stylix.colors`, bridged by home/stylix.nix.
  # =========================================================================
  stylix = {
    enable = true;
    image = ../wallpaper.jpg;     # flake-relative store path; updated by qs-apply-wallpaper
    polarity = "dark";
    autoEnable = false;           # palette-only — no per-app target conflicts
  };

  # qs-apply-wallpaper is defined in the `let` above (config-derived paths; its
  # exact store path is matched by the polkit rule below).
  environment.systemPackages = [ qsApplyWallpaper ];

  # =========================================================================
  # Passwordless polkit for qs-apply-wallpaper (EXACT path match)
  # =========================================================================
  # Without this rule, the dashboard's APPLY WALLPAPER button does nothing:
  # pkexec needs a polkit *authentication agent* (GUI prompter) to ask for a
  # password, and none ships with the Quickshell/Hyprland setup. This rule
  # pre-authorizes exactly this one action for members of wheel, so no prompt is
  # shown — the rebuild just runs.
  #
  # SECURITY: matches the EXACT resolved store path, NOT a substring. polkit
  # canonicalizes the pkexec'd /run/current-system/sw/bin/qs-apply-wallpaper
  # symlink down to /nix/store/<hash>-qs-apply-wallpaper/bin/qs-apply-wallpaper;
  # `prog ===` that exact string pre-authorizes ONLY the legit binary built into
  # THIS system — a wheel user can't get passwordless root by pkexec'ing a
  # differently-pathed binary whose name merely contains "qs-apply-wallpaper"
  # (the old `indexOf` substring match allowed exactly that). The path is
  # interpolated at build time, so it tracks the per-rebuild store hash.
  #
  # ACTIVATION: requires ONE manual `sudo nixos-rebuild switch` from a terminal
  # to land (the button itself can't bootstrap the rule). polkitd watches the
  # rules directory and reloads on activation, so it's live immediately after.
  # =========================================================================
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      var prog = action.lookup("program");
      if (action.id === "org.freedesktop.policykit.exec" &&
          prog === "${qsApplyWallpaperBin}" &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';
}
