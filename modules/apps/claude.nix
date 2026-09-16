# modules/apps/claude.nix
# Claude Code - AI-powered developer assistant for your terminal
# This module is designed for Home Manager (User-level)
{ inputs, pkgs, lib, ... }:

let
  isSupported = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
in
{
  # Only apply configuration if the platform is supported
  config = lib.mkIf isSupported {
    
    # 1. Install Claude Code
    # Uses the flake input 'claude-code' defined in your flake.nix
    home.packages = [
      inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    # 2. Universal Shell Aliases
    # This automatically handles Bash, Zsh, and Fish.
    # This replaces the 'initExtra' code that was causing your error.
    home.shellAliases = {
      c = "claude";
      cc = "claude --continue";
    };

    # (no config-dir seeding here — Claude Code reads ~/.claude, which the
    # configure-claude activation script in essentials.nix populates;
    # ~/.config/claude is read by nothing.)
  };
}
