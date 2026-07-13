# =========================================================================
# build → push → rollout for the hugo static site
# =========================================================================
# Requires omni-nix's k3s cluster + local registry (127.0.0.1:5000) running.
# k3s is on-demand — start it first:  sudo systemctl start k3s
# =========================================================================
set shell := ["bash", "-c"]

image := "localhost:5000/hugo-site"
tag   := "latest"
ns    := "default"
dep   := "hugo-site"

# Build the Nix image (no Dockerfile, no docker).
build:
    nix build .#image --out-link result

# Push to the local registry over HTTP (no docker).
push: build
    #!/usr/bin/env bash
    set -euo pipefail
    skopeo copy --dest-tls-verify=false \
      docker-archive:"$(readlink -f result)" \
      docker://"{{image}}:{{tag}}"

# Apply manifests + roll the Deployment so k3s pulls the new image.
deploy: push
    #!/usr/bin/env bash
    set -euo pipefail
    kubectl apply -f manifests/
    kubectl -n {{ns}} rollout restart deployment/{{dep}}
    kubectl -n {{ns}} rollout status   deployment/{{dep}}

# Local dev server (live reload) → http://localhost:1313.
serve:
    hugo server -D --buildDrafts

logs:
    kubectl -n {{ns}} logs deploy/{{dep}} -f

# Forward the cluster's :80 → local :8080.
forward:
    kubectl -n {{ns}} port-forward svc/{{dep}} 8080:80

shell:
    nix develop
