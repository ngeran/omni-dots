# =========================================================================
# AI TOOLS: docker-compose — declarative multi-container stacks, one command
# =========================================================================
# Why: the AI tooling ecosystem ships as compose files first — vector
# databases (Qdrant, Chroma), LLM observability (Langfuse, Phoenix), search
# (SearXNG) all publish a docker-compose.yml. Compose is the 30-second "try
# it locally" path BEFORE committing to k3s manifests:
#     docker compose up -d && curl localhost:3000   # evaluate it
#     docker compose down -v                        # throw it away
# Anything that survives evaluation gets promoted to the k3s lab
# (labs/k8s-telemetry pattern) or a NixOS module.
#
# Works against the system docker daemon (modules/apps/virtualization.nix);
# the local registry (labs/k8s-registry.nix) is unrelated to compose.
#
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    docker-compose
  ];
}
