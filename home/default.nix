{ inputs, config, pkgs, ... }:

{
  imports = [

  # --- NIXVIM ---
  inputs.nixvim.homeModules.nixvim
     
    ./apps.nix
    ./quickshell.nix
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
  ];

  home.username = "nikos";
  home.homeDirectory = "/home/nikos";

  programs.bash = {
    enable = true;
    shellAliases = {
      btw = "echo I use nixos btw";
      omni-apply = "sudo nixos-rebuild switch --flake ~/.omni-nix/#nixos-btw";
    };
  };

  home.stateVersion = "26.05";
}
