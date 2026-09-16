# =========================================================================
# AI TOOLS — one module per tool for AI / agent / MCP development
# =========================================================================
# This folder is the dedicated home for CLI tooling that supports AI-agent
# development (building agents, debugging MCP servers, inspecting LLM API
# traffic). Each tool gets its OWN file here (the one-module-per-tool pattern
# used across modules/apps/) so it can be added, commented out, or understood
# in isolation.
#
# WIRING: this directory is imported by modules/apps/dev-tools.nix (the
# "global CLI utilities, every machine" module), so BOTH hosts get everything
# here — the desktop AND the dell3440 laptop.
#
# NOT in this folder (they live elsewhere — one source of truth per package):
#   • Claude Code        → modules/apps/claude.nix
#   • opencode + MCP     → modules/apps/opencode.nix
#   • junos-mcp server   → modules/apps/junos-mcp/
#   • Ollama / Open WebUI → modules/ollama.nix, modules/open-webui.nix
#
{ ... }:

{
  imports = [
    ./jq.nix              # JSON processor — MCP/API payload inspection
    ./yq.nix              # YAML processor — k8s manifests + LLM config files
    ./uv.nix              # Python env manager — venvs + tool running for AI work
    ./tmux.nix            # session persistence — long agent runs survive disconnects
    ./git-delta.nix       # syntax-highlighted pagers — reviewing AI-written diffs
    ./docker-compose.nix  # one-command local AI stacks before k3s-ifying them
    ./websocat.nix        # WebSocket/SSE debugging — LLM streaming endpoints
  ];
}
