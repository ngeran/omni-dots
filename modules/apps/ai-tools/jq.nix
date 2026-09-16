# =========================================================================
# AI TOOLS: jq — JSON processor (the sed of JSON)
# =========================================================================
# Why it matters for AI/agent work: every layer of the stack speaks JSON —
# MCP tool payloads, LLM API requests/responses, opencode/claude settings,
# kubectl -o json output. jq turns "read the raw blob" into "query the
# fields", e.g.:
#     kubectl get pods -o json | jq '.items[].metadata.name'
#     cat response.json | jq '.choices[0].message.content'
#
# Installed system-wide (not per-project): it is infrastructure for the
# shell, like grep — every tool here assumes it exists.
#
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    jq
  ];
}
