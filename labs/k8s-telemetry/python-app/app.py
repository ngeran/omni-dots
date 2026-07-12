# Minimal Flask app for the k8s-telemetry lab.
#
# Swap in your real application here — the deployment workflow is identical:
#   docker build -t pyapp:dev .
#   docker save pyapp:dev -o /tmp/pyapp.tar
#   sudo k3s ctr -n k8s.io images import /tmp/pyapp.tar
# (then kubectl apply -f ../manifests/70-pyapp.yaml). The Deployment uses
# imagePullPolicy: Never, so k3s never tries to pull pyapp:dev from a registry.
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
