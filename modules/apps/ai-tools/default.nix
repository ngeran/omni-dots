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
# "global CLI utilities" module) — everything here lands system-wide on
# every host that imports dev-tools.
#
# NOT in this folder (they live elsewhere — one source of truth per package):
#   • Claude Code        → modules/apps/claude.nix
#   • opencode + MCP     → modules/apps/opencode.nix
#   • junos-mcp server   → modules/apps/junos-mcp/
#   • Ollama               → modules/ollama.nix
#
{ ... }:

{
  imports = [
    ./jq.nix              # JSON processor — MCP/API payload inspection
    ./yq.nix              # YAML processor — compose/CI/MCP config files
    ./uv.nix              # Python env manager — venvs + tool running for AI work
    ./tmux.nix            # session persistence — long agent runs survive disconnects
    ./git-delta.nix       # syntax-highlighted pagers — reviewing AI-written diffs
    ./docker-compose.nix  # one-command local AI stacks (compose-first evaluation)
    ./websocat.nix        # WebSocket/SSE debugging — LLM streaming endpoints
  ];
}
