# Python template — FastAPI *or* plain script

One scaffold, **two variants**. Pick one and everything (image entrypoint,
justfile recipes) follows it.

| `variant` | Use case | Image entrypoint |
|---|---|---|
| `"fastapi"` (default) | HTTP service / API | `uvicorn main:app` on :8080 |
| `"script"` | a script that runs and exits (worker, batch job, CLI) | `python /app/script.py` |

## Switch variant

Set the same value in **two** places (kept in sync — the flake builds the
image, the justfile runs/smoke-tests it):

```nix
# flake.nix
variant = "fastapi";   # or "script"
```
```just
# justfile
variant := "fastapi"   # or "script"
```

## Layout

```
├── flake.nix               # variant switch → image (entrypoint + venv via uv2nix)
├── pyproject.toml          # ─┐ SINGLE source of truth for Python deps
├── uv.lock                 # ─┘ (uv2nix builds the venv for BOTH dev shell + image)
├── justfile                # variant-aware run / build / test / check
└── app/
    ├── main.py             # FastAPI app    (variant = "fastapi")
    └── script.py           # plain script   (variant = "script")
```

## Run

```bash
# local — the devShell venv (built from pyproject.toml/uv.lock via uv2nix)
just run

# Nix-built OCI image (no Dockerfile) + docker smoke test
# (fastapi: load, run, curl / → 200 · script: run to exit 0)
just build
just test

# ruff + mypy (mypy advisory until you configure it)
just check

# change deps: edit pyproject.toml → `uv lock` (in the devShell) → rebuild
```

> The devShell's venv IS the image's venv (uv2nix, from uv.lock) — no
> `pip install`, no requirements.txt, no drift.

## Notes

- **Deps are the SAME for local dev and the image** — both come from
  `pyproject.toml` + `uv.lock` via [uv2nix](https://github.com/pyproject-nix/uv2nix).
  Edit `pyproject.toml`, run `uv lock` (in the devShell), then `just build`.
