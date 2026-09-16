# =========================================================================
# AI TOOLS: uv — Python environments & tool running (Astral's Rust rewrite)
# =========================================================================
# Why THIS and not pip/poetry/pipx: the AI ecosystem is Python-first (agent
# SDKs, LangGraph, eval harnesses, PyTorch), and uv is the fastest, most
# reliable way to manage it:
#   • per-project venvs from a lockfile        → uv sync
#   • huge wheels (torch/CUDA) resolve fast    → parallel, cached downloads
#   • one-shot tool running (like npx)         → uvx <tool>
#   • Python interpreters themselves           → uv python install 3.12
#
# Deliberate design fit: this system has NO global python3 (the devshell
# philosophy in home/devshell.nix — toolchains live per-project). uv
# completes that model instead of fighting it: projects pin their stack in
# pyproject.toml, `uv sync` materializes it into ./.venv, and direnv activates
# it. Global $HOME stays clean.
#
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    uv
  ];
}
