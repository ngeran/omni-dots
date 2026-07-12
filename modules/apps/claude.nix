# modules/apps/claude.nix
# Claude Code - AI-powered developer assistant for your terminal
{ config, inputs, pkgs, lib, ... }:

let
  isSupported = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
in
{
  config = lib.mkIf isSupported {
    # Nixpkgs configuration to allow unfree packages
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) [
        "claude-code"
        "claude"
      ] || config.nixpkgs.config.allowUnfree or false;

    # Add Claude Code to system packages
    # Combine both package definitions in one place
    environment.systemPackages = with pkgs; [
      inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default
    ] ++ lib.optionals config.programs.rofi.enable [
      # Add desktop entry if rofi is enabled
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
    ];

    # Shell aliases for convenience
    programs.bash.initExtra = lib.mkIf config.programs.bash.enable (lib.mkOptional ''
      alias c="claude"
      alias cc="claude --continue"
    '');

    programs.zsh.initExtra = lib.mkIf config.programs.zsh.enable (lib.mkOptional ''
      alias c="claude"
      alias cc="claude --continue"
    '');

    # Create Claude config directory
    system.activationScripts.claude-config = {
      text = ''
        if [ ! -d "$HOME/.config/claude" ]; then
          mkdir -p "$HOME/.config/claude"
          echo "Claude config directory created at $HOME/.config/claude"
        fi
      '';
      deps = [ "users" ];
    };
  };

  config.warnings = lib.mkIf (!isSupported) [
    "Claude Code is not supported on ${pkgs.stdenv.hostPlatform.system}. Skipping."
  ];
}
