"""Plain runnable script (variant = "script").

Runs to completion (exit 0). Run it locally (variant = "script"):
    just run      # from the repo root — runs app/script.py in the devShell venv

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
