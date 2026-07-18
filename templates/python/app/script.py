"""Plain runnable script (variant = "script").

Runs to completion (exit 0) → ideal for a Kubernetes Job. Run locally
(from app/, after `uv venv` in the repo root):
    uv run python script.py
In k8s it's deployed as a Job (manifests/script/job.yaml); `just deploy`
submits / re-runs it.

Add CLI args, a loop, env config, or network calls to suit your task.
"""
import os
import socket
import time


def main() -> None:
    name = os.environ.get("TASK_NAME", "pyapp-script")
    print(f"[{name}] running on {socket.gethostname()}…")

    # ── your work here ──────────────────────────────────────────────────
    for i in range(3):
        print(f"  step {i + 1}/3")
        time.sleep(1)
    # ────────────────────────────────────────────────────────────────────

    print(f"[{name}] done.")


if __name__ == "__main__":
    main()
