# Python template — FastAPI *or* plain script

One scaffold, **two variants**. Pick one and everything (image entrypoint,
manifests, justfile) follows it.

| `variant` | Use case | Entrypoint | K8s resource |
|---|---|---|---|
| `"fastapi"` (default) | HTTP service / API | `uvicorn main:app` on :8080 | `Deployment` + `Service` |
| `"script"` | a script that runs and exits (worker, batch job, CLI) | `python /app/script.py` | `Job` (runs to completion) |

## Switch variant

Set the same value in **two** places (kept in sync — the flake builds the image,
the justfile deploys the matching manifest):

```nix
# flake.nix
variant = "fastapi";   # or "script"
```
```just
# justfile
variant := "fastapi"   # or "script"
```

That's it — `just deploy` does the rest.

## Layout

```
├── flake.nix               # variant switch → image (entrypoint + deps)
├── justfile                # variant-aware build / push / deploy / run / logs
├── app/
│   ├── main.py             # FastAPI app    (variant = "fastapi")
│   ├── script.py           # plain script   (variant = "script")
│   └── requirements.txt    # LOCAL-dev deps (uv venv) — the image reads flake.nix, not this
└── manifests/
    ├── fastapi/            # Deployment + Service (variant = "fastapi")
    └── script/             # Job                 (variant = "script")
```

`just deploy` only applies `manifests/<variant>/`, so the unused variant's
manifests are inert — leave them or delete them.

## Run

```bash
# local (uvicorn for fastapi, python for script) — needs `uv venv` at repo root
uv venv && uv pip install -r app/requirements.txt
just run

# build → push (skopeo, no docker) → deploy to k3s
just deploy
just logs          # tail (Deployment for fastapi, Job pod for script)
just forward       # port-forward :8080 (fastapi only)
```

> Never `pip install` against Nix's Python (read-only → PEP-668). Always go
> through `uv` → the repo-root `.venv`.

## Notes

- **Image deps** come from `flake.nix` (`python3.withPackages`), **not**
  `requirements.txt`. For `variant = "script"`, add your runtime imports to the
  `withPackages` list in `flake.nix` (empty by default — the sample uses only the
  stdlib).
- **Re-running a Job:** Jobs are immutable, so `just deploy` deletes +
  re-applies `manifests/script/job.yaml` after each edit.
- **Graduation path:** for many/PyPI-only deps, swap `withPackages` for
  `buildPythonApplication` + `uv2nix` so one source of truth feeds both the
  image and local dev.
