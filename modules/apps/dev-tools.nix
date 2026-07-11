{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # CLI Utils
    fzf
    ripgrep
    fd
    git-lfs

    # Coding Stuff
    lua
    tailwindcss
    hugo

    # k8s / telemetry lab CLI — always available on the desktop. The k3s
    # SERVICE itself stays gated behind labs/k8s-telemetry/nix/k3s.nix (not
    # imported by default), but these lightweight clients are useful with or
    # without a local cluster. helm omitted (the lab uses plain YAML).
    kubectl
    k9s
    gnmic

  ];
}
