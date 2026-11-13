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
  # AI/agent-development CLI tools live in their own folder (one file per
  # tool, with a hub default.nix): jq/yq/uv/tmux/delta/compose/websocat.
  # Imported here — not in hosts/desktop — so BOTH hosts get them, matching
  # this module's "global CLI utilities, every machine" contract.
  imports = [
    ./ai-tools
  ];

  environment.systemPackages = with pkgs; [
    # ── CLI utilities ─────────────────────────────────────────────────────
    fzf
    ripgrep
    fd
    git-lfs

    # ── Scripting ─────────────────────────────────────────────────────────
    lua

    # ── Project recipe runner ─────────────────────────────────────────────
    # `just` drives each template's recipes (build / test / check / run —
    # see templates/<name>/justfile). Also listed in each template's
    # devShell so scaffolded projects carry it off-host.
    just
  ];
}
