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

    # ── Dev→image→k8s pipeline ────────────────────────────────────────────
    # `just` is the recipe runner that drives each project's build → push →
    # rollout loop (see templates/{python,hugo,react}/justfile). `skopeo`
    # pushes a Nix-built image (dockerTools.buildImage) to the local registry
    # WITHOUT docker — `nix build .#image` → skopeo copy docker-archive:…
    # docker://localhost:5000/<app>. Both are also listed in each template's
    # devShell so scaffolded projects carry them off-host.
    just
    skopeo

    # ── Kubernetes / telemetry lab clients ────────────────────────────────
    # Lightweight clients, useful with or without the k3s service running.
    # k3s itself is imported in hosts/desktop/default.nix (on-demand: it does
    # not auto-start at boot — `sudo systemctl start k3s` brings it up).
    # helm omitted (the lab uses plain YAML under labs/k8s-telemetry/manifests/).
    kubectl
    k9s
    gnmic
  ];
}
