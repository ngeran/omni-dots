"""Minimal Flask app.

The Nix image runs this under gunicorn:
    gunicorn app:app --bind 0.0.0.0:8080
(Local dev: `uv run flask --app app run --port 8080` after `uv venv`.)
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
