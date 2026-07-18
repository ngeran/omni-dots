"""Minimal FastAPI app (variant = "fastapi").

The Nix image runs this under uvicorn:
    uvicorn main:app --host 0.0.0.0 --port 8080
Local dev (from app/, after `uv venv` in the repo root):
    uv run uvicorn main:app --reload --port 8080   → http://localhost:8080
"""
import socket

from fastapi import FastAPI

app = FastAPI()
HITS = {"n": 0}


@app.get("/")
def index():
    HITS["n"] += 1
    return {
        "message": "hello from pyapp",
        "pod": socket.gethostname(),
        "hits": HITS["n"],
    }


@app.get("/healthz")
def healthz():
    return {"status": "ok"}
