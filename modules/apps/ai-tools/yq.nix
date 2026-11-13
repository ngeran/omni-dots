# =========================================================================
# AI TOOLS: yq — YAML/XML/TOML processor (jq's sibling for config files)
# =========================================================================
# Why: the config surface of this stack is YAML-heavy — MCP server
# definitions, CI files, docker-compose — and
# yq gives them the same query/patch workflow jq gives JSON:
#     yq '.services.web.image' docker-compose.yaml
#     yq -i '.mcp.server.enabled = true' config.yaml
#
# `yq-go` is mikefarah's Go implementation (the syntax used in its
# docs; colors, in-place edits, multi-document files). The package installs
# its binary as `yq`.
#
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    yq-go
  ];
}
