# Project Pipeline Guide v3 — dev → Nix image → k8s

The complete, **current** reference for the per-stack dev pipeline: scaffold or
migrate a project, build a reproducible container image with Nix (no Dockerfile),
deploy it to the local k3s cluster, and drive the pods.

> **What changed from v1 (`PIPELINE.md`):** Python moved from
> Flask/`requirements.txt`/`withPackages` to **FastAPI-or-script `variant` +
> uv2nix** (one source — `pyproject.toml`/`uv.lock` — for dev **and** image; the
> version-drift footgun is gone). React's manual `npmDepsHash` paste is now
> **`just relock`**. New recipes: **`just doctor` / `just test` / `just check`**
> (and React `just relock`); `just deploy` now uses `--timeout=120s` + surfaces
> crash logs. **All images run non-root (UID 1000)** with securityContext /
> resources / probes; nginx stacks listen on **:8080**.
>
> For the direnv / dev-shell deep-dive see [`DEV-ENVIRONMENTS.md`](DEV-ENVIRONMENTS.md).

---

## Table of contents

1. [Prerequisites (one-time)](#1-prerequisites-one-time)
2. [The mental model](#2-the-mental-model)
3. [Create a NEW project](#3-create-a-new-project)
   - [3.1 Python (FastAPI or script, uv2nix)](#31-new-python-project-fastapi-or-script-uv2nix)
   - [3.2 Hugo](#32-new-hugo-project)
   - [3.3 React + Tailwind](#33-new-react--tailwind-project)
4. [Migrate an EXISTING project](#4-migrate-an-existing-project)
5. [Build the image + deploy to k8s](#5-build-the-image--deploy-to-k8s-the-test-loop)
6. [Pod lifecycle — start / stop / kill / destroy](#6-pod-lifecycle--start--stop--kill--destroy)
7. [Reaching a deployed service](#7-reaching-a-deployed-service)
8. [Exposing services beyond localhost](#8-exposing-services-beyond-localhost)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Prerequisites (one-time)

```bash
omni-apply                       # installs `just` + `skopeo` globally (modules/apps/dev-tools.nix)
```

Before deploying, bring up the cluster (k3s is **on-demand**, it does not start at boot):

```bash
sudo systemctl start k3s         # bring the cluster up        (stop:  sudo systemctl stop k3s)
curl -s localhost:5000/v2/       # registry auto-starts → {}   (provided by labs/k8s-registry.nix)
kubectl get nodes                # → nixos-btw  Ready
```

First-ever k3s start needs a one-time bootstrap (k3s state lives on `/persist`):

```bash
sudo mkdir -p /persist/var/lib/rancher/k3s   # only before the VERY first start
```

`just doctor` (in any project) checks all of the above for you — k3s up, registry
reachable, and that your `flake.nix`/`app/` changes are `git add`-ed (golden rule 1).

---

## 2. The mental model

Each project is a directory containing a **`flake.nix`** that declares two things:

| Output | What it is |
|---|---|
| `devShells.default` | the dev tools — auto-loaded by `direnv` when you `cd` in |
| `packages.image` | a **reproducible OCI image** built by Nix (`dockerTools.buildImage`) — **no Dockerfile** |

`just` drives the loop between them:

```
just build   →   nix build .#image      (produces ./result, the image tarball)
just push    →   skopeo copy …          (pushes to localhost:5000, NO docker)
just deploy  →   kubectl apply + rollout (k3s pulls the new image)
```

**Golden rules (breaking these = silent failure):**

1. **`git add` before `just build`/`deploy`.** Flakes read the *git index*, not the
   working tree. An unstaged `flake.nix`, `app/`, `pyproject.toml`, `uv.lock`, or
   `package-lock.json` is invisible to the build. (`just doctor` warns on this.)
2. **`direnv allow` after editing `flake.nix` or `.envrc`.**
3. **Image strings stay in lockstep** across `flake.nix` (`name`/`tag`), the
   `justfile` (`image`/`tag`), and `manifests/*.yaml` (`image:`). Fixed tag
   (`:latest`) + `imagePullPolicy: Always` is intentional.

**Reproducibility:** every image is **fully reproducible from `flake.lock`** —
the same commit produces the same bytes. Python deps are pinned in `uv.lock`,
React's in `package-lock.json` (via `npmDepsHash`), Hugo's offline (nixpkgs). No
`pip install`/`npm install` happens at image build time.

---

## 3. Create a NEW project

### 3.1 New Python project (FastAPI or script, uv2nix)

```bash
mkdir ~/myapp && cd ~/myapp && git init
nix flake init -t ~/.omni-nix#python
git add -A
direnv allow
```

You get:

```
myapp/
├── flake.nix              # variant switch + uv2nix venv → image (non-root)
├── pyproject.toml         # ─┐ SINGLE source of truth for Python deps
├── uv.lock                # ─┘ (uv2nix builds the venv for BOTH dev shell + image)
├── .envrc                 # use flake
├── justfile               # build / push / deploy / run / logs / forward / doctor / test / check
├── app/
│   ├── main.py            # FastAPI app  (variant = "fastapi")
│   └── script.py          # plain script (variant = "script")
└── manifests/
    ├── fastapi/           # Deployment + Service (variant = "fastapi")
    └── script/            # Job                 (variant = "script")
```

**One scaffold, two variants.** Set the same value in **two** places (kept in
sync — the flake builds the image, the justfile deploys the matching manifest):

```nix
# flake.nix
variant = "fastapi";   # "fastapi" = HTTP service (uvicorn main:app on :8080)
                       # "script"  = runs to completion (python /app/script.py) → K8s Job
```
```just
# justfile
variant := "fastapi"   # or "script"
```

`just deploy` only applies `manifests/<variant>/`, so the unused variant's
manifests are inert — leave them or delete them.

**Deps — one source (uv2nix).** Both the dev shell and the image derive their
venv from `pyproject.toml` + `uv.lock`. To change deps:

```bash
# edit pyproject.toml [project] dependencies = [ ... ], then refresh the lock:
uv lock                                    # inside the devShell (or: nix run nixpkgs#uv -- lock)
git add pyproject.toml uv.lock             # golden rule 1 — uv.lock must be tracked
just build                                 # rebuilds the image with the new venv
```

> [!important] No more requirements.txt, no more drift
> v1 had `requirements.txt` (local) vs `withPackages` (image) drifting independently
> — that's what caused the real `fastapi==0.111` (local) vs `0.136` (image) →
> pod HTTP 500 incident. uv2nix **kills that**: `pyproject.toml`/`uv.lock` feed
> both, so dev and prod are always the same versions. There is no
> `requirements.txt` and no `withPackages` list to keep in sync.

**Run locally** — the devShell venv is already populated from `uv.lock` (no
`uv pip install`, never `pip install` against Nix's Python — read-only → PEP-668):

```bash
just run            # fastapi: uvicorn main:app --reload --port 8080
                    # script:  python script.py
```

(`just run` uses the devShell venv's binaries directly — the same venv the image ships.)

> [!warning] "address already in use" on :8080
> `pkill -f uvicorn` — or run on `--port 8000` (edit the `justfile` run recipe).

**Deploy:** `just deploy` (see [§5](#5-build-the-image--deploy-to-k8s-the-test-loop)).

---

### 3.2 New Hugo project

```bash
mkdir ~/mysite && cd ~/mysite && git init
nix flake init -t ~/.omni-nix#hugo
git add -A
direnv allow
```

You get a minimal Hugo site under `site/` (`site/hugo.toml`, `site/content/`,
`site/layouts/`) plus the image definition. **Run locally:**

```bash
just serve        # cd site && hugo server -D  → http://localhost:1313 (live reload)
```

(The Hugo source lives in `site/`, so `just serve` cds there for you.) Add a theme
(submodule) and content as usual:

```bash
git submodule add https://github.com/adityatelange/hugo-PaperMod site/themes/PaperMod
echo 'theme = "PaperMod"' >> site/hugo.toml
hugo new content/posts/hello.md     # then edit +  just serve
```

**Deploy:** `just deploy`. Hugo builds **offline** inside the image (no
lock/hash step) — nixpkgs ships the extended Hugo (SCSS / asset pipeline).

If your theme uses a Node asset pipeline (Tailwind/PostCSS):

```bash
npm install        # one-time, inside the devShell (nodejs_22 is provided) — run in site/
```

`just check` validates the site builds cleanly (`hugo --gc --minify` to a temp dir).

---

### 3.3 New React + Tailwind project

```bash
mkdir ~/myweb && cd ~/myweb && git init
nix flake init -t ~/.omni-nix#react
git add -A
direnv allow
```

This gives you a Vite + React + TypeScript scaffold under `app/` **without**
Tailwind. Add Tailwind (v4) on top:

```bash
cd app
npm install                              # generates package-lock.json
npm install tailwindcss @tailwindcss/vite
cd ..
```

Edit `app/vite.config.ts` to register the Tailwind plugin:

```ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  plugins: [react(), tailwindcss()],
});
```

Create `app/src/index.css` and import it from `main.tsx`:

```css
@import "tailwindcss";
```
```ts
// app/src/main.tsx — add at the top:
import "./index.css";
```

Now use Tailwind classes in `App.tsx`, e.g. `<h1 className="text-3xl font-bold">`.

**Run locally:**

```bash
just serve        # cd app && npm run dev  → http://localhost:5173 (HMR)
```

**One-time reproducibility step** (inherent to Nix-built JS) — set the deps hash.
`just relock` computes it from `package-lock.json` and writes it into `flake.nix`
for you:

```bash
just relock        # runs prefetch-npm-deps, sed-writes npmDepsHash into flake.nix
git add app/package-lock.json flake.nix   # golden rule 1 — both must be tracked
just build         # succeeds
```

(The template ships `npmDepsHash = lib.fakeHash` as a placeholder; `just relock`
replaces it. Re-run `just relock` whenever `package.json`/lockfile changes.)

**Deploy — two targets:**

- **Local k3s** (default; file storage works natively): `just deploy`.
- **Vercel** (public URL): add a root `vercel.json` and set the project's
  **Root Directory to the repo root** (not `app/` — Vercel auto-detects
  `app/package.json` and points there, which hides root `vercel.json` and
  `/api/`, making every `/api/*` call return `404: NOT_FOUND`).

  Frontend-only needs just an SPA rewrite:

  ```json
  {
    "buildCommand": "cd app && npm install && npm run build",
    "outputDirectory": "app/dist",
    "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }]
  }
  ```

  **Full-stack (any create/edit/delete) needs a database** — Vercel serverless
  has a **read-only filesystem**, so file-based storage doesn't persist
  (symptom: `FUNCTION_INVOCATION_FAILED` on cold start, or `500`/`503` on
  writes). Add a serverless API under `/api/` (entry `api/index.py` exposing
  the ASGI `app`, with `sys.path.insert` for sibling imports), back it with a
  persistent store selected by env (Neon Postgres via `DATABASE_URL` works
  well; `psycopg[binary]`), seed from bundled `api/seed/*.md`, and set
  `DATABASE_URL` in Vercel env vars (all environments) + redeploy. Full recipe,
  the `/api` rewrite, the schema, and the gotchas: `references/vercel.md`.

  Rule of thumb: **file-based data → k3s; public URL → Vercel + a DB.**

---


## 4. Migrate an EXISTING project

The pattern is the same for all stacks: copy the project in, drop the matching
template's `flake.nix` + `.envrc` + `justfile` + `manifests/` alongside your
existing code, point the flake at your code, `git add`, `direnv allow`.
(`nix flake init -t …` won't overwrite existing files.)

**Python** — point `pyproject.toml` at your real deps, then `uv lock`:

```bash
cd path/to/existing-python-project
git init && nix flake init -t ~/.omni-nix#python
# edit pyproject.toml: name/version + [project] dependencies = [ your real deps ]
uv lock                                       # generates uv.lock from your deps
git add -A && direnv allow
```

Move your code under `app/` (or edit `flake.nix`'s `appSource` to point at your
dir, e.g. `cp -r ${./src}/. $out/app/`). Set `variant` (`"fastapi"` if it's a web
service, `"script"` if it runs to completion). Delete the template's `app/main.py`
or `app/script.py` sample if it conflicts. Then `just deploy`.

> The image's deps come **only** from `pyproject.toml`/`uv.lock` (uv2nix) —
> there is no separate `withPackages` list and no `requirements.txt`. One source.

**Hugo** — move your existing site under `site/` (or edit `flake.nix`'s
`staticAssets` builder: `cp -r ${./site}/. build/` → point at your Hugo project
dir, e.g. `${./.}` if the repo root *is* the project root). Theme submodules
carry over: `git submodule update --init`. `git add -A`, `direnv allow`, `just deploy`.

**React** — if your app isn't under `app/`, edit `flake.nix`'s `reactBuild`:
`src = ./.;` (the dir holding `package.json`). Then:

```bash
npm install          # generate/refresh package-lock.json
just relock          # set npmDepsHash
git add -A && direnv allow
just deploy
```

---

## 5. Build the image + deploy to k8s (the test loop)

From inside any project dir (with k3s up):

```bash
just build       # nix build .#image  →  ./result  (the image tarball, no Dockerfile)
just push        # skopeo → localhost:5000/<app>:latest  (no docker in the loop)
just deploy      # kubectl apply manifests/ + rollout restart + rollout status
just logs        # tail the pod
just forward     # port-forward :8080 → curl localhost:8080
```

`just deploy` chains `push` which chains `build`, so `just deploy` alone does the
whole thing. Edit code → `git add -A` → `just deploy` is the entire loop. The
rollout `status` now has **`--timeout=120s`** and, on failure, prints the pod
table + the last crash log (`kubectl logs … --previous`) — so a `CrashLoopBackOff`
surfaces immediately instead of hanging.

### The full recipe set (per stack)

| Recipe | What it does |
|---|---|
| `just build` | `nix build .#image` → `./result` |
| `just push` | `skopeo copy` → registry (passes `--insecure-policy`) |
| `just deploy` | apply manifests + rollout restart + `rollout status --timeout=120s` (crash logs on fail) |
| `just run` (py) / `just serve` (hugo, react) | local dev server from the devShell |
| `just logs` | tail the pod |
| `just forward` | port-forward the Service → `localhost:8080` |
| **`just doctor`** | pre-flight: k3s up, `localhost:5000` reachable, git index clean for build inputs |
| **`just test`** | local smoke: `docker load` + `docker run` (non-root) + `curl` → expect HTTP 200 |
| **`just check`** | lint/type/build check the build doesn't: py `ruff`+`mypy`, react `tsc`+`eslint`, hugo `--gc --minify` |
| **`just relock`** (react only) | recompute `npmDepsHash` from `package-lock.json` + write it into `flake.nix` |

### Test the Nix-built image locally (`just test`)

Symmetric to a `docker run` smoke test, automated. Loads `./result` into docker,
runs it as the **non-root UID 1000** the image ships, and curls `/`. Needs
`docker` (on the host), but it's **not** part of the required loop — Nix builds
and pushes without any docker daemon:

```bash
just test        # build + docker load + run + curl  →  "HTTP 200 from /  OK"
```

(The nginx stacks mount `--tmpfs /tmp:uid=1000` so the non-root nginx can write
its pid/temp — `just test` handles this; a bare `docker run` without it would hit
a `/tmp` permission error on hugo/react.)

**Per-stack image notes:**

| Stack | Image deps come from | One-time step |
|---|---|---|
| Python | `pyproject.toml`/`uv.lock` → uv2nix venv | `uv lock` when deps change |
| Hugo | nixpkgs Hugo (offline build) | none |
| React | `package.json` → `buildNpmPackage` | `just relock` when deps change |

### Safe-by-default pods

Every template's image runs as **non-root (UID 1000)** — `flake.nix` sets
`config.User` and bakes a `/etc/passwd` entry; the manifests add
`securityContext` (`runAsNonRoot`, `runAsUser 1000`, `readOnlyRootFilesystem`,
`capabilities.drop: ["ALL"]`, `allowPrivilegeEscalation: false`,
`seccompProfile: RuntimeDefault`), `resources.requests/limits`, and
liveness/readiness probes. nginx stacks listen on **:8080** (non-root can't bind
<1024); the Service still fronts on `:80`.

---

## 6. Pod lifecycle — start / stop / kill / destroy

**Kubernetes reality check:** you don't usually start/stop individual pods. Pods
are managed by a **Deployment** (a controller) that keeps N replicas alive. So:

- "start" = scale the Deployment to ≥1 (or apply the manifest)
- "stop" = scale to 0 (pods go away, Deployment stays)
- "kill one pod" = delete it (the Deployment **recreates** a new one)
- "destroy for good" = delete the Deployment

Throughout, `<ns>` = the namespace (`default` for new templates, `lab` for the
telemetry lab) and `<dep>` = the Deployment name (`pyapp` / `hugo-site` / `react-app`).

### See what's running

```bash
kubectl get pods -n <ns>                      # this project's pods
kubectl get pods -A                           # ALL namespaces
kubectl get deploy,svc,pods -n <ns>           # the full set
kubectl describe pod <pod-name> -n <ns>       # events, why it's stuck
```

### Logs & shell

```bash
kubectl logs <pod-name> -n <ns>               # stdout
kubectl logs <pod-name> -n <ns> -f            # follow (tail)
kubectl logs <pod-name> -n <ns> --previous    # logs of the LAST (crashed) instance
```

> ⚠️ **`kubectl exec -it <pod> -- sh` does NOT work on these images.** Nix-built
> `dockerTools` images are minimal — they contain your app, not a shell or
> coreutils. For an interactive shell, add a debug shell to the image
> (`copyToRoot = [ … pkgs.bash pkgs.coreutils ]`), or use
> `kubectl debug -it <pod> --image=busybox --target=<container> -- sh`.

### Start / scale / restart

```bash
kubectl apply -f manifests/                    # create the Deployment + Service (START)
kubectl scale deploy/<dep> -n <ns> --replicas=0   # STOP: drain to 0 (no pods, Deploy stays)
kubectl rollout restart deploy/<dep> -n <ns>   # graceful restart (new pods, then old gone)
kubectl rollout status  deploy/<dep> -n <ns>   # watch the rollout finish
kubectl rollout undo    deploy/<dep> -n <ns>   # roll BACK to the previous version
```

(`just deploy` does `rollout restart` + `rollout status` for you.)

### Kill a single pod / destroy everything

```bash
kubectl delete pod <pod-name> -n <ns>          # killed; the Deployment recreates a new one
kubectl delete -f manifests/                   # destroy the Deployment + Service
```

### Stop the whole cluster

```bash
sudo systemctl stop k3s        # tears down all pods/services; state on /persist survives
sudo systemctl start k3s       # brings it back; workloads re-apply from manifests
```

---

## 7. Reaching a deployed service

```bash
just forward                    # port-forward svc → localhost:8080
# then in another terminal:
curl http://localhost:8080/
```

This always works regardless of DNS/ingress. For the **lab** (which has a
traefik ingress + Pi-hole DNS):

```bash
curl http://pyapp.lab.local/                              # if Pi-hole DNS is up
curl -H 'Host: pyapp.lab.local' http://10.0.0.86/         # without lab DNS
```

New (`#python`/`#hugo`/`#react`) templates deploy to `default` as a plain
ClusterIP Service — use `just forward`. Add an Ingress (copy
`labs/k8s-telemetry/manifests/90-ingress.yaml` as a template) if you want a
hostname. To reach a `default`-namespace service from **other devices on your
LAN**, see [§8](#8-exposing-services-beyond-localhost).

---

## 8. Exposing services beyond localhost

`just forward` ([§7](#7-reaching-a-deployed-service)) binds to `127.0.0.1` — only
*this* machine can reach the app. To make a default-namespace app reachable from
**other devices on the LAN** (a phone, another box), pick one of these. All serve
plain HTTP with no auth — see the caveat at the end.

First, get the node's LAN IP (single-node k3s → it's the host's IP):

```bash
kubectl get nodes -o wide --no-headers | awk '{print $1, $6}'   # → nixos-btw  10.0.0.86
```

### a) `port-forward --address 0.0.0.0` — quick, temporary

```bash
kubectl -n default port-forward svc/pyapp --address 0.0.0.0 8080:8080
# then from any LAN device: http://10.0.0.86:8080/
```

Good for a one-off demo; dies when the foreground terminal closes.

### b) NodePort Service — simple, persistent

Change the Service `type` to `NodePort` (e.g. in `manifests/service.yaml`):

```yaml
spec:
  type: NodePort
  ports:
    - name: http
      port: 8080
      targetPort: http      # named → the container's 8080 (non-root)
      nodePort: 30080        # 30000–32767
```

```bash
kubectl apply -f manifests/service.yaml
curl http://10.0.0.86:30080/         # from any LAN device
```

### c) Traefik Ingress + hostname — clean, scalable

k3s ships **Traefik** on host `:80`/`:443`. An `Ingress` gives a real hostname +
path/vhost routing for many services + a place for TLS:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: pyapp
  namespace: default
spec:
  rules:
    - host: pyapp.home
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: pyapp
                port:
                  number: 80
```

```bash
kubectl apply -f manifests/ingress.yaml
curl -H 'Host: pyapp.home' http://10.0.0.86/   # works immediately — no DNS needed
```

(DNS: add `pyapp.home → 10.0.0.86` via Pi-hole/CoreDNS, or `/etc/hosts` on each
device. The lab already does this via Pi-hole.)

> [!warning] Home lab only — not the open internet
> All three serve **plain HTTP with no auth**. Fine on a trusted home network;
> do **not** expose them to the internet without TLS (Ingress + real certs) and auth.

---

## 9. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `just build` says it can't find `.#image` / "no flake" | `flake.nix` not git-tracked → `git add flake.nix .envrc justfile app manifests` (`just doctor` warns) |
| `just build` ignores my Python dep / app edit | `pyproject.toml`/`uv.lock`/`app/` not `git add`-ed (golden rule 1). Run `uv lock` after editing `pyproject.toml`, then `git add uv.lock`. |
| Pod `CrashLoopBackOff` / `Error` | `just deploy` now prints the crash log automatically; or `kubectl logs <pod> --previous`. Most common: a Python dep missing from `pyproject.toml`, or stale/wrong `npmDepsHash` (React → `just relock`). |
| `ModuleNotFoundError: No module named 'X'` (Python) | add `X` to `pyproject.toml` `[project] dependencies`, then `uv lock` + `just build`. (No more `withPackages`.) |
| `ImagePullBackOff` | registry down (`curl localhost:5000/v2/`), or k3s off, or image/tag mismatch between `flake.nix`, `justfile`, manifest. |
| React build: `npmDepsHash` mismatch | `just relock` (recomputes from `package-lock.json` + writes it into `flake.nix`). |
| `just test` fails on hugo/react with `/tmp` permission denied | expected if you `docker run` by hand without the tmpfs — `just test` mounts `--tmpfs /tmp:uid=1000` for you; don't drop it. |
| `kubectl exec … -- sh` fails | expected — Nix images have no shell. See [§6](#6-pod-lifecycle--start--stop--kill--destroy). |
| `python3`/`node` "not found" after `cd` | `flake.nix` not git-tracked, or `direnv allow` stale. |
| k3s won't start (first time) | `sudo mkdir -p /persist/var/lib/rancher/k3s` then `sudo systemctl restart k3s`. |

### Full reset of a project in the cluster

```bash
kubectl delete -f manifests/        # destroy
just deploy                         # rebuild image + recreate
```

### Clean the registry (reclaim space)

```bash
sudo docker stop registry && sudo docker volume rm registry-data && sudo docker start registry
# then just push again before the next just deploy
```
