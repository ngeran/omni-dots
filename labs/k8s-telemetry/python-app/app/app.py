"""Minimal Flask app for the k8s-telemetry lab.

The Nix image runs this under gunicorn (flake.nix -> packages.image):
    gunicorn app:app --bind 0.0.0.0:8080
Local dev (`just run` from the repo root — SAME entry point the image runs):
    cd app && gunicorn app:app --reload --bind 0.0.0.0:8080  ->  http://localhost:8080

Swap in your real application here — the deployment workflow is identical.
Image: `just build` (Nix, no Dockerfile). Push/deploy: `just push`, `just deploy`
(skopeo -> localhost:5000/pyapp:latest -> k3s).
"""
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
