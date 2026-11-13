# =========================================================================
# AI TOOLS: jq — JSON processor (the sed of JSON)
# =========================================================================
# Why it matters for AI/agent work: every layer of the stack speaks JSON —
# MCP tool payloads, LLM API requests/responses, opencode/claude settings,
# docker inspect output. jq turns "read the raw blob" into "query the
# fields", e.g.:
#     docker inspect <container> | jq '.[0].State.Status'
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
