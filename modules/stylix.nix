{ config, pkgs, ... }:

{
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

  # =========================================================================
  # qs-apply-wallpaper — helper invoked by the Quickshell dashboard
  # =========================================================================
  # Copies the chosen image into the flake tree as wallpaper.jpg, then rebuilds
  # so Stylix regenerates the palette. The dashboard runs this via `pkexec`.
  #
  # NOTE: paths are hardcoded to /home/nikos because pkexec runs this as root,
  # where $HOME is /root. Single-user machine.
  # =========================================================================
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "qs-apply-wallpaper" ''
      set -euo pipefail
      SRC="''${1:?usage: qs-apply-wallpaper <image-path>}"
      [ -f "$SRC" ] || { echo "not a file: $SRC" >&2; exit 1; }
      cp -f -- "$SRC" "/home/nikos/.omni-nix/wallpaper.jpg"
      chown nikos:users "/home/nikos/.omni-nix/wallpaper.jpg" 2>/dev/null || true
      exec nixos-rebuild switch --flake "/home/nikos/.omni-nix#nixos-btw"
    '')
  ];

  # =========================================================================
  # Passwordless polkit for qs-apply-wallpaper
  # =========================================================================
  # Without this rule, the dashboard's APPLY WALLPAPER button does nothing:
  # pkexec needs a polkit *authentication agent* (GUI prompter) to ask for a
  # password, and none ships with the Quickshell/Hyprland setup. This rule
  # pre-authorizes exactly this one action for members of wheel, so no prompt
  # is shown at all — the rebuild just runs.
  #
  # MATCHING: polkit canonicalizes the program path through the symlink, so
  # `action.lookup("program")` returns the resolved store path
  # (`/nix/store/<hash>-qs-apply-wallpaper/bin/qs-apply-wallpaper`), NOT the
  # `/run/current-system/sw/bin/...` symlink we invoke. Matching the exact
  # symlink therefore NEVER hits. We match by binary basename instead — robust
  # to both forms and to the store hash changing on every rebuild.
  #
  # ACTIVATION: requires ONE manual `sudo nixos-rebuild switch` from a terminal
  # to land (the button itself can't bootstrap the rule). polkitd watches the
  # rules directory and reloads on activation, so it's live immediately after.
  # =========================================================================
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      var prog = action.lookup("program");
      if (action.id === "org.freedesktop.policykit.exec" &&
          prog && prog.indexOf("/qs-apply-wallpaper") !== -1 &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';
}
