# Project Pipeline Guide — dev → Nix image → k8s

The complete reference for the **per-stack dev pipeline**: scaffold or migrate a
project, build a reproducible container image with Nix (no Dockerfile), deploy
it to the local k3s cluster, and drive the pods.

> For the direnv / dev-shell deep-dive see [`DEV-ENVIRONMENTS.md`](DEV-ENVIRONMENTS.md).
> This doc is the one-stop guide for the **image + deploy + k8s** parts.

---

## Table of contents

1. [Prerequisites (one-time)](#1-prerequisites-one-time)
2. [The mental model](#2-the-mental-model)
3. [Create a NEW project](#3-create-a-new-project)
   - [3.1 Python](#31-new-python-project)
   - [3.2 Hugo](#32-new-hugo-project)
   - [3.3 React + Tailwind](#33-new-react--tailwind-project)
4. [Migrate an EXISTING project](#4-migrate-an-existing-project)
   - [4.1 Python](#41-migrate-an-existing-python-project)
   - [4.2 Hugo](#42-migrate-an-existing-hugo-project)
   - [4.3 React](#43-migrate-an-existing-react-project)
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
   working tree. An unstaged `flake.nix` or `app/` is invisible to the build — and
   a build that silently drops half your files is the single most common failure.
2. **`direnv allow` after editing `flake.nix` or `.envrc`.**
3. **Image strings stay in lockstep** across `flake.nix` (`name`/`tag`), the
   `justfile` (`image`/`tag`), and `manifests/*.yaml` (`image:`). Fixed tag
   (`:latest`) + `imagePullPolicy: Always` is intentional.
4. **`.gitignore` has no inline comments.** `node_modules/  # deps` matches
   *nothing* (the `#…` becomes part of the pattern), so the dir stays tracked and
   gets baked into every image. Put every comment on its **own line**, above the
   pattern. See [§9](#9-troubleshooting) if `node_modules/`/`public/` won't untrack.

---

## 3. Create a NEW project

### 3.1 New Python project

```bash
mkdir ~/myapp && cd ~/myapp && git init
nix flake init -t ~/.omni-nix#python
git add -A
direnv allow
```

You get:

```
myapp/
├── flake.nix              # devShell (python3/uv/ruff/mypy) + image (flask/gunicorn)
├── .envrc                 # use flake  (+ auto-activates .venv if present)
├── justfile               # build / push / deploy / logs / forward
├── app/
│   ├── app.py             # ← your code (sample Flask app)
│   └── requirements.txt   # ← your deps (local dev)
└── manifests/
    ├── deployment.yaml    # namespace: default, port 8080
    └── service.yaml
```

> [!important] Two frameworks, one pipeline
> The scaffold ships a **Flask** sample app (`app/app.py`; the image runs `gunicorn app:app`). To use **FastAPI** you change the app *and* `flake.nix` (the image's deps + start command) — see "FastAPI variant" below. Deploy is always `just deploy` ([§5](#5-build-the-image--deploy-to-k8s-the-test-loop)) for either framework.

**Run locally.** First, install deps into the **root** `.venv` — that's the one
`.envrc` activates and `uv run` uses (never run `uv venv` inside `app/`):

```bash
uv venv && uv pip install -r app/requirements.txt
```

> [!tip] Deps live in the root `.venv`
> `.envrc` activates `./.venv`, and `uv run` honours that `VIRTUAL_ENV`. Run the install from the repo root; a venv created inside `app/` is ignored by `uv run`.

#### Flask (scaffold default)

```bash
uv run flask --app app run --port 8080     # → http://localhost:8080
```

#### FastAPI variant

1. Replace the app: write your FastAPI app as `app/main.py` (object named `app`);
   delete `app/app.py`.
2. Set `app/requirements.txt`:
   ```txt
   fastapi
   uvicorn
   jinja2            # only if you use templates
   python-multipart  # only if you use Form(...)
   ```
3. Run **from inside `app/`** — template dirs / module paths are relative to the process cwd:
   ```bash
   cd app
   uv run uvicorn main:app --reload --port 8080   # → http://localhost:8080
   ```
4. Make the **image** FastAPI too — edit `flake.nix` (`packages.image`):
   ```nix
   appPython = pkgs.python3.withPackages (p: [ p.fastapi p.uvicorn p.jinja2 p.python-multipart ]);
   Cmd = [ "${appPython}/bin/uvicorn" "main:app" "--host" "0.0.0.0" "--port" "8080" ];
   ```
   (Flask stays `gunicorn app:app --bind 0.0.0.0:8080`.)

> [!warning] Version drift between `requirements.txt` and nixpkgs
> They drift independently. Real example: local pinned `fastapi==0.111.0` (Starlette 0.37) while nixpkgs shipped `fastapi 0.136.3` (Starlette 1.1, which **removed** the old `TemplateResponse(name, {"request": ...})` signature) → pod returned HTTP 500 while local dev returned 200. Use the new `TemplateResponse(request, name, ctx)` (works on both), and/or bump `requirements.txt` to match nixpkgs.

> [!warning] "address already in use" on :8080
> `pkill -f uvicorn; pkill -f gunicorn` — or just run on `--port 8000`.

> ⚠️ Never `pip install` against Nix's Python (read-only → PEP-668). Always go
> through `uv` → the project `.venv`.

**Deploy:** `just deploy` (see [§5](#5-build-the-image--deploy-to-k8s-the-test-loop)).

---

### 3.2 New Hugo project

```bash
mkdir ~/mysite && cd ~/mysite && git init
nix flake init -t ~/.omni-nix#hugo
git add -A
direnv allow
```

You get a minimal Hugo site (`site/hugo.toml`, `site/content/`, `site/layouts/`)
plus the image definition. **Run locally:**

```bash
just serve        # hugo server -D  → http://localhost:1313 (live reload)
```

Add a theme (submodule) and content as usual:

```bash
git submodule add https://github.com/adityatelange/hugo-PaperMod themes/PaperMod
echo 'theme = "PaperMod"' >> site/hugo.toml
hugo new content/posts/hello.md     # then edit +  just serve
```

**Deploy:** `just deploy`. Hugo builds **offline** inside the image (no
lock/hash step) — nixpkgs ships the extended Hugo (SCSS / asset pipeline).

If your theme uses a Node asset pipeline (Tailwind/PostCSS):

```bash
npm install        # one-time, inside the devShell (nodejs_22 is provided)
```

> [!note] The image runs **nginx** serving the built site on **:80**
> `manifests/deployment.yaml` expects `containerPort: 80`; `just forward` maps
> local `8080 → 80`. The template's `nginx.conf` already carries the three things
> a from-scratch `dockerTools` image needs to run nginx in a pod — `daemon off;`,
> `user root;`, and a `/tmp` layer. Leave them in if you edit the flake; if a pod
> crash-loops, see [§9](#9-troubleshooting).

---

### 3.3 New React + Tailwind project

```bash
mkdir ~/myweb && cd ~/myweb && git init
nix flake init -t ~/.omni-nix#react
git add -A
direnv allow
```

This gives you a Vite + React + TypeScript scaffold **without** Tailwind. Add
Tailwind (v4) on top:

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
cd app && npm run dev        # → http://localhost:5173 (HMR)
```

**One-time reproducibility step** (inherent to Nix-built JS) — set the deps hash:

```bash
nix build .#image            # FAILS, printing the correct sha256
# paste it into flake.nix → npmDepsHash, then re-run:
nix build .#image            # succeeds
```

(Or `nix run nixpkgs#prefetch-npm-deps -- app/package-lock.json`.) Re-do this
whenever `package.json`/lockfile changes.

**Deploy:** `just deploy`.

---

## 4. Migrate an EXISTING project

The pattern is the same for all stacks: copy the project in, drop the matching
template's `flake.nix` + `.envrc` + `justfile` + `manifests/` alongside your
existing code, point the flake at your code, `git add`, `direnv allow`.

> [!warning] `nix flake init` won't overwrite existing files
> If the repo already has a `.envrc` / `.gitignore` / `flake.nix`, the template
> skips them and instead writes a fresh **sample** scaffold (e.g. `site/` for
> Hugo, `app/app.py` for Python) next to your real content. You must reconcile
> the three config files by hand, then delete the sample scaffold — or the build
> serves the placeholder, not your site.

### 4.1 Migrate an existing Python project

*(e.g. `biterrors` — FastAPI + Textual TUI)*

```bash
cd path/to/existing-python-project
git init                                # if not already
nix flake init -t ~/.omni-nix#python    # writes flake.nix/.envrc/justfile/app/manifests/
```

`nix flake init` won't overwrite existing files, so your code is safe. Now
**point the image at your real entry point** — edit `flake.nix`:

```nix
# If your app lives in ./src and the WSGI/ASGI app is src/main:app:
appSource = pkgs.runCommand "app-src" { } ''
  mkdir -p $out/app
  cp -r ${./src}/. $out/app/
'';
# …config.WorkingDir = "/app";
#   config.Cmd = [ "${appPython}/bin/gunicorn" "main:app" "--bind" "0.0.0.0:8080" ];
```

Add your **runtime deps** to the image — add them to `withPackages`:

```nix
appPython = pkgs.python3.withPackages (p: [ p.flask p.gunicorn p.requests p.uvicorn ]);
# (every package your app imports at runtime must be listed here)
```

Delete the template's `app/app.py` sample if it conflicts, `git add -A`,
`direnv allow`, then:

```bash
rm -rf .venv && uv venv && uv pip install -r requirements.txt   # recreate venv
just deploy
```

> ⚠️ **Two dependency sources** (keep in sync):
> - `requirements.txt` → your **local** `uv` venv (dev).
> - `flake.nix` → `withPackages` → what the **image** ships (prod).
>
> Add a dep to **both**. (A single source of truth is the Increment-3 `uv2nix`
> upgrade — not built yet.)

---

### 4.2 Migrate an existing Hugo project

*(e.g. `ngeranio` — Hugo + Tailwind/PostCSS)*

```bash
cd path/to/existing-hugo-site
git init
nix flake init -t ~/.omni-nix#hugo
```

Move your existing site content under `site/` (or edit `flake.nix`'s
`staticAssets` builder to point at your content dir, e.g. `${./.}` if the Hugo
project root *is* the repo root). The key line in `flake.nix`:

```nix
staticAssets = pkgs.runCommand "hugo-site" { nativeBuildInputs = [ pkgs.hugo ]; } ''
  mkdir -p $out build
  cp -r ${./site}/. build/        # ← point this at your Hugo project dir
  chmod -R u+w build
  hugo -s "$PWD/build" --minify --destination "$out"
'';
```

If you use a Node asset pipeline:

```bash
npm install                # nodejs_22 is in the devShell
just serve                 # hugo server -D
```

Theme submodules carry over: `git submodule update --init`. `git add -A`,
`direnv allow`, `just deploy`.

> [!warning] Migration gotchas (all hit on `ngeranio`)
> - **Repo-root sites.** If `hugo.toml`/`content/`/`themes/` live at the repo
>   root (not under `site/` — common for older sites), point `staticAssets` at
>   `${./.}`, **not** `${./site}`, and `git rm -r site/` the sample scaffold the
>   template wrote. Otherwise the image serves the placeholder page.
> - **`.gitignore` inline comments break patterns** (golden rule 4). On
>   `ngeranio`, `node_modules/  # …` matched nothing → 1439 `node_modules/` +
>   82 `public/` files were tracked and got copied into every image build. Move
>   comments to their own line, then untrack: `git rm --cached -r node_modules public`.
> - **Build inputs must be git-tracked.** Nix sees only the git index. Verify
>   with `git ls-files themes content static assets` — anything untracked
>   silently 404s in the built image.
> - **No Node needed at build time.** `js.Build` uses Hugo's embedded esbuild
>   and there's no `resources.PostCSS` step, so `node_modules` isn't needed for
>   the offline image build — only for local `just serve` if you change CSS.

---

### 4.3 Migrate an existing React project

*(e.g. `ggeran` — Next.js / React / Tailwind)*

```bash
cd path/to/existing-react-project
git init
nix flake init -t ~/.omni-nix#react
```

If your app isn't under `app/`, either move it there or edit `flake.nix`:

```nix
reactBuild = pkgs.buildNpmPackage {
  src = ./.;                # ← point at the dir holding package.json
  # …
};
```

Then:

```bash
npm install                 # generate/refresh package-lock.json
nix build .#image           # → fails with the correct hash; paste into npmDepsHash
nix build .#image           # succeeds
git add -A && direnv allow
just deploy
```

> Existing `node_modules/` from another distro usually still works on NixOS.
> If a native addon breaks after a Node bump: `npm rebuild` (or
> `rm -rf node_modules && npm install`).

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
whole thing. Edit code → `git add -A` → `just deploy` is the entire loop.

> [!tip] `just deploy`'s `rollout status` can hang
> The deploy recipe waits on `rollout status` with **no `--timeout`**. If the pod
> never goes `Ready` (e.g. `CrashLoopBackOff`), `just deploy` blocks until you
> interrupt it. When iterating on a crashing pod, run the steps yourself with a
> bound: `kubectl -n default rollout restart deploy/<dep>` then
> `kubectl -n default rollout status deploy/<dep> --timeout=120s`, and inspect
> `kubectl get pods` / `kubectl logs` directly.

### Test the Nix-built image locally before push

Symmetric to the Docker path's `docker run` smoke test: load `./result` into a
local container runtime and curl it. This needs `docker` (available on the host),
but it is **not** part of the required loop — Nix builds and pushes without any
docker daemon. Optional sanity check before you push:

```bash
docker load < result                                       # ./result is the Nix-built OCI tarball (gzipped)
docker run --rm -p 8081:8080 localhost:5000/pyapp:latest   # :8081 avoids clashing with a local dev server
# in another shell:
curl -i http://localhost:8081/                             # expect HTTP 200
```

The image loads under whatever `name:tag` `flake.nix` declared
(`localhost:5000/pyapp:latest` here). For Hugo the container serves on **:80**, so
map `8081:80` and `curl http://localhost:8081/`.

**Per-stack notes for the image:**

| Stack | Image deps come from | One-time step |
|---|---|---|
| Python | `flake.nix` → `python3.withPackages (p: [ … ])` | none |
| Hugo | nixpkgs Hugo (offline build), served by **nginx on :80** | none |
| React | `package.json` → `buildNpmPackage` | set `npmDepsHash` (see [3.3](#33-new-react--tailwind-project)) |

The image is **fully reproducible** from `flake.lock` — the same commit produces
the same bytes. No `pip install` at build time, no Dockerfile, no Docker daemon
required to build or push.

### Alternative: manual Docker path

> [!note] Not the canonical path
> The Nix flake above is the supported, reproducible pipeline. This Dockerfile fallback is for when you genuinely need a plain `docker build` — debugging, or a dependency nixpkgs doesn't ship. It pins its own deps from `requirements.txt` (self-contained) at the cost of reproducibility and the "git-tracked files only" guarantee.

For the Python stack, add a `Dockerfile` + `.dockerignore` at the repo root:

```dockerfile
FROM python:3.13-slim
WORKDIR /app
COPY app/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ ./
EXPOSE 8080
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

`.dockerignore` is essential — without it `docker build .` bakes in the ~50 MB
`.venv` (deps come from `requirements.txt` inside the image, so the venv is dead
weight):

```text
**/.venv
.venv
result
result-*
.direnv
.git
__pycache__
*.pyc
```

Then build, smoke-test, push, and roll — same manifests as the Nix path:

```bash
docker build  -t localhost:5000/pyapp:latest .
docker run    --rm -p 8081:8080 localhost:5000/pyapp:latest   # smoke test → curl :8081
docker push            localhost:5000/pyapp:latest            # localhost is auto-insecure for docker
kubectl apply -f manifests/
kubectl -n default rollout restart deployment/pyapp
```

Golden rule 3 still applies: if you change the image **name or tag**, keep it in
lockstep across the `docker build -t`/`push` tag and `manifests/*.yaml`.

> [!tip] Dockerfile vs Nix — why Nix is the default
> | | Dockerfile | Nix flake |
> |---|---|---|
> | Reproducible from a lock? | no (PyPI at build time) | yes (`flake.lock`) |
> | Deps source | `requirements.txt` (self-consistent) | nixpkgs (can drift from `requirements.txt`) |
> | Untracked files | included (plain `COPY`) | excluded (must `git add -A`) |
> | Build/push tool | `docker` | `nix` + `skopeo` (no docker) |

---

## 6. Pod lifecycle — start / stop / kill / destroy

**Kubernetes reality check:** you don't usually start/stop individual pods. Pods
are managed by a **Deployment** (a controller) that keeps N replicas alive. So:

- "start" = scale the Deployment to ≥1 (or apply the manifest)
- "stop" = scale to 0 (pods go away, Deployment stays)
- "kill one pod" = delete it (the Deployment **recreates** a new one)
- "destroy for good" = delete the Deployment

Throughout, `<ns>` = the namespace (`default` for new templates, `lab` for the
telemetry lab) and `<dep>` = the Deployment name (`pyapp` / `hugo-site` /
`react-app`).

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

### Start / scale

```bash
kubectl apply -f manifests/                    # create the Deployment + Service (START)
kubectl scale deploy/<dep> -n <ns> --replicas=3   # scale up to 3 pods
kubectl scale deploy/<dep> -n <ns> --replicas=0   # STOP: drain to 0 (no pods, Deploy stays)
```

### Restart / roll out a new version

```bash
kubectl rollout restart deploy/<dep> -n <ns>   # graceful restart (new pods, then old gone)
kubectl rollout status  deploy/<dep> -n <ns>   # watch the rollout finish
kubectl rollout undo    deploy/<dep> -n <ns>   # roll BACK to the previous version
```

(`just deploy` does `rollout restart` + `rollout status` for you.)

### Kill a single pod

```bash
kubectl delete pod <pod-name> -n <ns>          # killed; the Deployment recreates a new one
```

This is the fastest way to force a pod to restart (e.g. it's wedged but the
image is correct). The replacement gets a new name.

### Destroy everything (stop + remove)

```bash
kubectl delete deploy/<dep>  -n <ns>           # destroy the Deployment + its pods
kubectl delete svc/<dep>     -n <ns>           # destroy the Service
# or in one shot:
kubectl delete -f manifests/                   # deletes everything the manifests declared
```

After `delete -f manifests/`, the project is gone from the cluster (the image
stays in the registry until you prune it). Re-create any time with
`kubectl apply -f manifests/` or `just deploy`.

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
*this* machine can reach the app. To make a default-namespace `#python` / `#hugo`
/ `#react` app reachable from **other devices on the LAN** (a phone, another
box), pick one of these. All serve plain HTTP with no auth — see the caveat at
the end.

First, get the node's LAN IP (single-node k3s → it's the host's IP):

```bash
kubectl get nodes -o wide --no-headers | awk '{print $1, $6}'   # → nixos-btw  10.0.0.86
```

### a) `port-forward --address 0.0.0.0` — quick, temporary

Bind the forward to every interface instead of loopback:

```bash
kubectl -n default port-forward svc/pyapp --address 0.0.0.0 8080:8080
```

Then from any LAN device: `http://10.0.0.86:8080/`.

Good for a one-off demo. Trade-offs: it lives only as long as the foreground
terminal stays open, dies on disconnect, and each port forwards only one
service. Nothing persists across reboots.

### b) NodePort Service — simple, persistent

Expose the Service on a fixed high port (30000–32767) on the node's IP. Change
the Service `type` to `NodePort` (e.g. in `manifests/service.yaml`):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: pyapp
  namespace: default
spec:
  type: NodePort
  selector:
    app: pyapp
  ports:
    - name: http
      port: 8080
      targetPort: 8080
      nodePort: 30080        # 30000–32767
```

```bash
kubectl apply -f manifests/service.yaml
curl http://10.0.0.86:30080/         # from any LAN device
```

Survives reboots and needs no foreground process. Trade-offs: you get an ugly
high port, one service per nodePort, and you must leave that port open on the
host firewall.

### c) Traefik Ingress + hostname — clean, scalable

k3s ships **Traefik** as its ingress controller (listening on host `:80`/`:443`),
so an `Ingress` gives you a real hostname, port 80, path/vhost routing for many
services, and a place to hang TLS. Worth it once you have more than one service
or want `http://pyapp.home` instead of `http://10.0.0.86:30080`:

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
                  number: 8080
```

```bash
kubectl apply -f manifests/ingress.yaml     # save the YAML above as manifests/ingress.yaml
curl -H 'Host: pyapp.home' http://10.0.0.86/   # works immediately — no DNS needed
curl http://pyapp.home/                         # needs the name to resolve → see below
```

**DNS:** Traefik routes by `Host`, but the hostname must still resolve to the
node. Either add a local DNS record (Pi-hole / CoreDNS: `pyapp.home → 10.0.0.86`),
or add `10.0.0.86 pyapp.home` to `/etc/hosts` on each device that should reach
it. The **lab** already does this via Pi-hole ([§7](#7-reaching-a-deployed-service));
default-namespace apps need you to add the record yourself.

> [!warning] Home lab only — not the open internet
> All three methods serve **plain HTTP with no authentication**: anyone on the
> same network can read or spoof the traffic, and the app itself is likely
> unauthenticated. That's an acceptable trade-off on a trusted home network. Do
> **not** forward these ports to the internet or expose them on an untrusted
> network without adding TLS (an Ingress with real certificates) and auth (on
> the app, or via Traefik middleware).

---

## 9. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `just build` says it can't find `.#image` / "no flake" | `flake.nix` not git-tracked → `git add flake.nix .envrc justfile app manifests` |
| Pod `CrashLoopBackOff` / `Error` | `kubectl logs <pod> --previous`. Most common: a runtime dep missing from `withPackages` (Python) or wrong `npmDepsHash` (React). |
| Hugo pod: `getpwnam("nobody")`, `mkdir() "/tmp/…"`, or a `Completed` exit-0 loop | nginx in a from-scratch image needs `daemon off;`, `user root;`, and a `/tmp` layer. The template's `nginx.conf` has all three — diff your hand-written flake against `~/.omni-nix/templates/hugo/flake.nix`. |
| `ModuleNotFoundError: No module named 'X'` (Python) | add `X` to `withPackages` in `flake.nix` (the image's deps), not just `requirements.txt`. |
| `ImagePullBackOff` | registry down (`curl localhost:5000/v2/`), or k3s off, or image/tag mismatch between `flake.nix`, `justfile`, manifest. |
| skopeo: "no policy.json found" | the justfile already passes `--insecure-policy`; if running skopeo by hand, add it. |
| `node_modules/`/`public/` baked into every build; "dirty tree" won't clear | `.gitignore` has **no inline comments** — `node_modules/  # deps` matches nothing, so the dir stays tracked and gets copied into `${./.}`. Put comments on their own line; untrack with `git rm --cached -r node_modules public`. |
| `just deploy` hangs forever | the recipe's `rollout status` has no `--timeout`; the pod is stuck (not `Ready`). Run `rollout status … --timeout=120s` by hand and check `kubectl get pods` / `kubectl logs`. |
| React build: hash mismatch | re-run `nix run nixpkgs#prefetch-npm-deps -- app/package-lock.json`, paste into `npmDepsHash`. |
| `kubectl exec … -- sh` fails | expected — Nix images have no shell. See [§6](#6-pod-lifecycle--start--stop--kill--destroy). |
| `python3`/`node` "not found" after `cd` | `flake.nix` not git-tracked, or `direnv allow` stale. |
| k3s won't start (first time) | `sudo mkdir -p /persist/var/lib/rancher/k3s` then `sudo systemctl restart k3s`. |

### Full reset of a project in the cluster

```bash
kubectl delete -f manifests/        # destroy
just deploy                         # rebuild image + recreate
```

### Clean the registry (reclaim space)

The registry holds every pushed tag. It's a docker volume `registry-data` — to
wipe it entirely:

```bash
sudo docker stop registry && sudo docker volume rm registry-data && sudo docker start registry
```

(You'll need to `just push` again before the next `just deploy`.)
