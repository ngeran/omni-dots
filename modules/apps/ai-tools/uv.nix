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
# Design fit: python3 IS present globally, but only as the quickshell bar's
# omarchy-xray plugin backend (modules/apps/essentials.nix) — it is not a
# general-purpose toolchain. uv keeps project stacks isolated: projects pin
# theirs in pyproject.toml, `uv sync` materializes it into ./.venv, and
# direnv activates it. Global $HOME stays clean.
#
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    uv
  ];
}
