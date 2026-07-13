# Minimal Flask app for the k8s-telemetry lab.
#
# Swap in your real application here — the deployment workflow is identical.
# The image is now built by Nix (see ./flake.nix) and pushed via skopeo:
#   just build     # nix build .#image  → ./result
#   just push      # skopeo → localhost:5000/pyapp:latest  (no docker)
#   just deploy    # applies ../manifests/70-pyapp.yaml + rolls the Deployment
# k3s pulls over plain HTTP via the registries.yaml mirror
# (labs/k8s-registry.nix); imagePullPolicy is Always. The old `docker save |
# sudo k3s ctr images import` + `imagePullPolicy: Never` path is gone.
import os
import socket

from flask import Flask

app = Flask(__name__)
HITS = {"n": 0}


@app.route("/")
def index():
    HITS["n"] += 1
    return (
        f"hello from pyapp\n"
        f"pod hostname: {socket.gethostname()}\n"
        f"requests served: {HITS['n']}\n"
    )


@app.route("/healthz")
def healthz():
    return "ok\n"


if __name__ == "__main__":
    # 0.0.0.0 so the pod is reachable on its IP (not just loopback).
    port = int(os.environ.get("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
