# =========================================================================
# DEV TOOLS — global CLI utilities (system-wide, every machine)
# =========================================================================
#
# Cross-project CLI tools that belong in every shell on every host. Language
# toolchains (hugo, tailwind, node, python) are intentionally NOT here — they
# live in per-project shells now (home/devshell.nix → templates/dev/).
#
# Previously `hugo` and `tailwindcss` were ALSO listed here, duplicating the
# (now-removed) home packages in programming.nix. Removed to avoid shadowing.
#
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # ── CLI utilities ─────────────────────────────────────────────────────
    fzf
    ripgrep
    fd
    git-lfs

    # ── Scripting ─────────────────────────────────────────────────────────
    lua

    # ── Kubernetes / telemetry lab clients ────────────────────────────────
    # The k3s SERVICE itself stays gated behind labs/k8s-telemetry/nix/k3s.nix
    # (opt-in, not imported by default), but these lightweight clients are
    # useful with or without a local cluster. helm omitted (lab uses YAML).
    kubectl
    k9s
    gnmic
  ];
}
