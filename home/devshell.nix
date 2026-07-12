# =========================================================================
# DEVELOPMENT ENVIRONMENT — per-project shells via direnv + Nix flakes
# =========================================================================
#
# PHILOSOPHY
# ----------
# Language toolchains (nodejs, python, hugo, tailwind, ...) are NOT installed
# globally. Each project ships a `flake.nix` that declares the exact tools it
# needs as a `devShell`, and `direnv` loads that shell automatically the
# moment you `cd` into the project. `cd` out, and those tools vanish from
# $PATH. The system and $HOME stay clean:
#
#   • no version conflicts between projects
#   • no PEP-668 "externally-managed-environment" pip errors
#     (Nix's Python is read-only; deps come from per-project venvs / `uv`)
#   • no `npm_config_prefix` / ~/.npm-global hacks
#
# The language packages that used to live in modules/apps/programming.nix and
# modules/apps/dev-tools.nix were removed on purpose — they belong in each
# project's flake.nix now. See templates/dev/ for a ready-made scaffold.
#
# WHAT THIS MODULE INSTALLS (the only two things that MUST be global)
#   1. direnv       — the auto-loader; hooks into bash
#   2. nix-direnv   — caches the flake evaluation so `use flake` is instant
#
# SCAFFOLD A NEW PROJECT:
#   nix flake init -t ~/.omni-nix#dev
# (see README.md → "Development environments")
#
{ config, pkgs, ... }:

{
  # ── Auto-loading dev shells ────────────────────────────────────────────
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;   # home/default.nix sets bash as the shell
    nix-direnv.enable = true;       # caches `use flake` → instant, no rebuild lag

    config = {
      # Also honour a project's plain .env file alongside the flake shell.
      load_dotenv = true;
    };
  };

  # Silence direnv's per-load log banner; errors still print.
  home.sessionVariables.DIRENV_LOG_FORMAT = "";
}
