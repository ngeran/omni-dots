{ inputs, config, pkgs, ... }:

{
  imports = [

  # --- NIXVIM ---
  inputs.nixvim.homeModules.nixvim
     
    ./apps.nix
    ./quickshell.nix
    ./hypridle.nix              # ★ idle daemon as a supervised systemd user unit
    ./chromium.nix              # ★ browser with keyring + NVDEC + native-Wayland flags
    ./stylix.nix
    ./notifications.nix
    ./git.nix
    ./dotfiles.nix
    ./devshell.nix              # ★ direnv + nix-direnv (per-project dev shells)
    ../modules/apps/essentials.nix
    ../modules/apps/programming.nix
    ../modules/apps/nixvim/default.nix
    ../modules/apps/video-editing.nix
    ../modules/apps/claude.nix
    ../modules/apps/opencode.nix    # ★ opencode CLI wired to local ollama (qwen2.5-coder:32b)
  ];

  home.username = "nikos";
  home.homeDirectory = "/home/nikos";

  # Enable the standalone `home-manager` CLI so you can run `home-manager switch`
  # directly. The flake still owns activation via nixos-rebuild (omni-apply).
  programs.home-manager.enable = true;

  programs.bash = {
    enable = true;
    shellAliases = {
      btw = "echo I use nixos btw";
      # Rebuild from the EXACT locked inputs — this never pulls anything new.
      omni-apply = "sudo nixos-rebuild switch --flake ~/.omni-nix/#nixos-btw";
      # Update everything, MANUALLY, when you decide (~monthly is plenty).
      # Moves flake.lock to the latest commit of each input branch
      # (nixos-26.05, nixos-hardware master, nixvim main, ...) and rebuilds.
      # Afterwards, commit flake.lock so the repo records what you run.
      # Rollback if an update misbehaves:
      #   sudo nixos-rebuild switch --rollback   (or older entry in boot menu)
      # Bisect a bad update per-input:
      #   nix flake lock --update-input <name>   (e.g. nixpkgs, nixvim)
      omni-update = "nix flake update --flake ~/.omni-nix/ && sudo nixos-rebuild switch --flake ~/.omni-nix/#nixos-btw";
    };
  };

  home.stateVersion = "26.05";
}
