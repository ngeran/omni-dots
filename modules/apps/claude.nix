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

    # 3. Ingested workflow skills (adapted from efficient-vibe-coding)
    # Deployed per-skill-dir so ~/.claude/skills/ stays a real, writable dir —
    # it's a hybrid: plain dirs + symlinks into ~/.agents/skills/ (skills CLI).
    # SKILL.md files are static, never written at runtime, so read-only store
    # symlinks are safe (same rule as the fastfetch/rofi/tmux whole-dir case).
    home.file = {
      ".claude/skills/plan-first".source = ../../configs/claude-skills/plan-first;
      ".claude/skills/verify-work".source = ../../configs/claude-skills/verify-work;
      ".claude/skills/token-hygiene".source = ../../configs/claude-skills/token-hygiene;
    };

    # (no config-dir seeding here — Claude Code reads ~/.claude, which the
    # configure-claude activation script in essentials.nix populates;
    # ~/.config/claude is read by nothing.)
  };
}
