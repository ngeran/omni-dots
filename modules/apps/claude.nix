# modules/apps/claude.nix
# Claude Code - AI-powered developer assistant for your terminal
# 
# This module installs Claude Code, Anthropic's terminal-based AI assistant
# that can help with coding, debugging, and development tasks.
#
# Usage:
#   - Run `claude` in your terminal to start the interactive session
#   - Use `claude --continue` to resume the last session
#   - Configure via ~/.config/claude/settings.json
#
# References:
#   - https://github.com/ryoppippi/nix-claude-code
#   - https://docs.anthropic.com/en/docs/claude-code

{ config, inputs, pkgs, lib, ... }:

let
  # Determine if we're running on x86_64-linux (Claude Code only supports this)
  isSupported = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
in
{
  # Only enable on supported platforms
  # Claude Code currently only supports x86_64-linux
  # If you're on aarch64-linux (ARM server), this will be skipped
  config = lib.mkIf isSupported {
    # Nixpkgs configuration to allow unfree packages
    # Claude Code is proprietary software from Anthropic
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) [
        "claude-code"      # The CLI tool
        "claude"           # Alternative name sometimes used
      ] || config.nixpkgs.config.allowUnfree or false;

    # Add Claude Code to system packages
    environment.systemPackages = with pkgs; [
      # Use the package from the claude-code flake input
      # Using stdenv.hostPlatform.system to avoid deprecation warnings
      inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    # Optional: Set up shell integration for better Claude experience
    # This adds helpful aliases and environment variables
    programs.bash.initExtra = lib.mkIf config.programs.bash.enable (lib.mkOptional ''
      # Claude Code aliases
      alias c="claude"
      alias cc="claude --continue"
      
      # Optional: Set default model or preferences
      # export ANTHROPIC_DEFAULT_MODEL="claude-3-5-sonnet-20241022"
    '');

    # Optional: Zsh integration if you use Zsh
    programs.zsh.initExtra = lib.mkIf config.programs.zsh.enable (lib.mkOptional ''
      # Claude Code aliases
      alias c="claude"
      alias cc="claude --continue"
    '');

    # Optional: Fish shell integration
    programs.fish.interactiveShellInit = lib.mkIf config.programs.fish.enable (lib.mkOptional ''
      # Claude Code aliases
      alias c="claude"
      alias cc="claude --continue"
    '');

    # Optional: Create a configuration directory with default settings
    # This ensures ~/.config/claude exists with proper permissions
    system.activationScripts.claude-config = {
      text = ''
        # Create Claude config directory if it doesn't exist
        if [ ! -d "$HOME/.config/claude" ]; then
          mkdir -p "$HOME/.config/claude"
          echo "Claude config directory created at $HOME/.config/claude"
        fi
      '';
      # Run this after the home directory is ready
      deps = [ "users" ];
    };

    # Optional: Add Claude to your desktop applications menu
    # Creates a .desktop file for integration with application launchers
    environment.systemPackages = lib.mkIf config.programs.rofi.enable (with pkgs; [
      (makeDesktopItem {
        name = "claude-code";
        exec = "claude";
        icon = "terminal";
        desktopName = "Claude Code";
        comment = "AI-Powered Development Assistant";
        categories = [ "Development" "Utility" ];
        terminal = true;
        type = "Application";
      })
    ]);
  };

  # Error message for unsupported platforms
  config.warnings = lib.mkIf (!isSupported) [
    "Claude Code is not supported on ${pkgs.stdenv.hostPlatform.system}. "
    + "Claude Code currently only runs on x86_64-linux. "
    + "Skipping claude.nix module installation."
  ];
}
