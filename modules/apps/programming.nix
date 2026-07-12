{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    hugo
    python3
    python3Packages.pip
    python3Packages.virtualenv
    nodejs
    tailwindcss
    fontconfig
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
  ];

  fonts.fontconfig.enable = true;

  home.sessionVariables = {
    npm_config_prefix = "$HOME/.npm-global";
    # Point Claude directly to your clean un-tracked key file via env sequence
    ANTHROPIC_AUTH_TOKEN_FILE = "$HOME/.config/secrets/zai_key";
    # kubectl / k3s lab. The kubeconfig is runtime-written by k3s (not a store
    # path), so point kubectl at the user copy in ~/.kube/config. Set globally —
    # harmless when k3s is off (kubectl just reports a missing file). See
    # labs/k8s-telemetry/CHEATSHEET.md.
    KUBECONFIG = "$HOME/.kube/config";
  };

  programs.bash.initExtra = ''
    export PATH="$HOME/.npm-global/bin:$PATH"
  '';

  # NOTE: ~/.claude/settings.json is intentionally NOT managed by home.file.
  # It is written by the `configure-claude` activation script in essentials.nix,
  # which injects ANTHROPIC_AUTH_TOKEN from ~/.config/secrets/zai_key. Managing
  # it here as well made home-manager fight the activation script every switch:
  # each switch left a real file that home-manager then tried to back up, and the
  # accumulating .backup files eventually blocked switches ("would be clobbered").
  # The activation script is the sole, authoritative writer of this file.
}
