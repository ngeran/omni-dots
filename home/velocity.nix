{ inputs, config, pkgs, ... }:

{
  # ── Velocity — the quickshell bar/settings rice (P3) ────────────────────────
  # The HM module lives in the velocity flake itself (the live config dir,
  # ~/.config/quickshell) — imported HERE, in the same file that enables it,
  # so options and values can never drift apart.
  imports = [ inputs.velocity.homeManagerModules.default ];

  # One `omni-apply` ships everything the rice needs:
  #   - CLI tools (cliphist, wl-clipboard, wf-recorder, wtype, slurp, …)
  #   - the rice fonts (Doto, Space Grotesk/Mono, nerd symbols)
  #   - the velocity-cliphist systemd user unit (+ the wayland gate)
  #   - THE bar unit: quickshell-bar (velocity owns it — quickshell.nix no
  #     longer defines it; environment.lua's explicit start stays as a no-op)
  #   - ~/.config/hypr/velocity-binds.lua — rendered from the keybinds single
  #     source (tools/keybinds-default.json); hyprland.lua requires it after
  #     keybindings.lua, which keeps only the non-velocity binds now
  #   - ~/.config/velocity/keybinds.json — the SUPER+K cheat sheet's source
  # The lock (SUPER+L → velocity-lock) gets its PAM service from the flake's
  # NixOS module, imported in hosts/desktop/default.nix.
  programs.velocity = {
    enable = true;

    # Reuse the SAME overridden quickshell package that quickshell.nix builds
    # (qt5compat on QML2_IMPORT_PATH) — never a second store copy.
    quickshellPackage = config.programs.quickshell.package;
  };
}
