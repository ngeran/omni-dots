# =========================================================================
# AI TOOLS: yq — YAML/XML/TOML processor (jq's sibling for config files)
# =========================================================================
# Why: the config surface of this stack is YAML-heavy — k8s manifests
# (labs/k8s-telemetry/manifests/), MCP server definitions, CI files — and
# yq gives them the same query/patch workflow jq gives JSON:
#     yq '.spec.containers[0].image' pod.yaml
#     yq -i '.mcp.server.enabled = true' config.yaml
#
# `yq-go` is mikefarah's Go implementation (the syntax used in kubectl-era
# docs; colors, in-place edits, multi-document files). The package installs
# its binary as `yq`.
#
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    yq-go
  ];
}
