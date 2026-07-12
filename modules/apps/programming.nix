# =========================================================================
# PROGRAMMING — cross-project foundations (fonts + dev-service env)
# =========================================================================
#
# Language toolchains (nodejs, python, hugo, tailwind) USED to live here and
# in dev-tools.nix. They have been moved to PER-PROJECT shells — see
# home/devshell.nix and templates/dev/. This keeps $HOME clean and lets each
# project pin its own versions.
#
# What remains here is genuinely cross-project:
#   • programming fonts — used by every editor/terminal
#   • dev-service env vars — Claude gateway key path + kubeconfig location
#
{ config, pkgs, ... }:

{
  # =========================================================================
  # 1. Programming Fonts
  # =========================================================================
  # Editor/terminal fonts, installed user-wide. (fonts.fontconfig is a Home
  # Manager option; the system-wide font set lives in modules/fonts.nix.)
  home.packages = with pkgs; [
    fontconfig
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
  ];
  fonts.fontconfig.enable = true;

  # =========================================================================
  # 2. Dev-service Environment Variables
  # =========================================================================
  home.sessionVariables = {
    # Point Claude Code at the un-tracked key file (see essentials.nix →
    # configure-claude activation script). Env fallback path, never a literal.
    ANTHROPIC_AUTH_TOKEN_FILE = "$HOME/.config/secrets/zai_key";

    # kubectl / k3s lab. The kubeconfig is runtime-written by k3s (not a
    # store path), so point kubectl at the user copy in ~/.kube/config. Set
    # globally — harmless when k3s is off (kubectl just reports a missing
    # file). See labs/k8s-telemetry/CHEATSHEET.md.
    KUBECONFIG = "$HOME/.kube/config";
  };
}
