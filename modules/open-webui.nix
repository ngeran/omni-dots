# =========================================================================
# Open WebUI — chat UI + docs RAG front-end for the local AI stack
# =========================================================================
# WHY STANDALONE (native NixOS), NOT a k3s pod via the project pipeline:
#  • The pipeline (Nix image → localhost:5000 registry → k3s) is for apps we
#    BUILD (Flask/Hugo/React). This is upstream software; nixpkgs ships it
#    (0.11.0) with a real module — nothing to containerize.
#  • It must talk to HOST Ollama (modules/ollama.nix). Native = plain
#    127.0.0.1:11434. A pod would need OLLAMA_HOST=0.0.0.0 + a cni0-scoped
#    firewall hole + a PVC — three new failure modes for zero benefit.
#  • k3s is ON-DEMAND on this box (wantedBy = [] in labs/k8s-telemetry).
#    The chat UI is a daily-driver tool; it must not depend on the cluster
#    being up. This service is light (~300 MB RAM) and auto-starts.
# If the AI stack later grows into a multi-service lab (Qdrant, rerankers)
#    exposed on the LAN, revisit — that's the moment a k3s Deployment under
#    labs/ starts paying for itself.
#
# RAG: embeddings run through OLLAMA (RAG_EMBEDDING_ENGINE=ollama +
# nomic-embed-text, pulled via loadModels). That REQUIRES
# OLLAMA_MAX_LOADED_MODELS=2 in modules/ollama.nix — with the old limit of 1,
# every RAG query would evict the resident LLM and force a 20 GB reload.
#
# NOTE: ollama itself stays on-demand — after boot the UI shows "Ollama
# offline" until `sudo systemctl start ollama`. Deliberate (see ollama.nix).
# =========================================================================
{ ... }:

{
  services.open-webui = {
    enable = true;
    host = "127.0.0.1";   # localhost only — no firewall exposure, no auth
                           # needed from the network side
    port = 8080;

    environment = {
      # Host Ollama daemon (the ONLY VRAM arbiter on this machine).
      OLLAMA_BASE_URL = "http://127.0.0.1:11434";

      # RAG through Ollama embeddings — same daemon, no separate embedding
      # service, nothing extra in VRAM worth mentioning (nomic ≈ 0.5 GB).
      RAG_EMBEDDING_ENGINE = "ollama";
      RAG_EMBEDDING_MODEL = "nomic-embed-text";

      # No login screen: the port is bound to 127.0.0.1 only, so the browser
      # session IS the auth boundary. (First-run admin signup still happens
      # if this is ever unset — it's a UI QoL toggle, not a security control.)
      WEBUI_AUTH = "False";
    };
    # State (sqlite DB, uploaded docs, vector index) stays on the root SSD
    # in /var/lib/open-webui — it's KBs-to-MBs of metadata, not blobs; the
    # heavy stuff (model weights) is already on INLAND via modules/ollama.nix.
  };
}
