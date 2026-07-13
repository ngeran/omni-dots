# 🪐 Omni-Nix Flake Architecture

A declarative NixOS + Home Manager flake for the **`nixos-btw`** machine (x86_64-linux, NixOS 26.05, AMD CPU/GPU desktop). It installs the OS, packages, services, and **ingests application configs** — and backs up to GitHub.

## Two repos

| Repo | Path | GitHub remote | Holds |
|---|---|---|---|
| **omni-dots** (this repo) | `~/.omni-nix` | `github.com/ngeran/omni-dots` | the flake: system + home config, packages, and ingested configs (fastfetch, rofi, hypr) |
| **velocity** | `~/.config/quickshell` | `github.com/ngeran/velocity` | the QML desktop shell — kept separate (actively edited in place, writes runtime files) |

## Directory structure

```text
~/.omni-nix/
├── flake.nix              # entry point: inputs + the nixos-btw system
├── flake.lock             # pinned inputs → reproducibility
├── wallpaper.jpg          # Stylix palette source (large binary, intentional)
│
├── configs/               # ★ ingested application config trees (checked in)
│   ├── fastfetch/         #   deployed whole-dir → ~/.config/fastfetch
│   ├── rofi/              #   deployed whole-dir → ~/.config/rofi
│   └── hypr/              #   deployed PER-FILE (dir must stay writable)
│
├── core/                  # base system: bootloader, user, nix settings
├── hosts/desktop/         # this machine's hardware + compositor (Hyprland)
│
├── home/                  # Home Manager config (user: nikos)
│   ├── default.nix        # wiring hub — imports the modules below
│   ├── dotfiles.nix       # ★ ingests configs/* into ~/.config (xdg.configFile)
│   ├── devshell.nix       # ★ direnv + nix-direnv (per-project dev shells)
│   ├── git.nix            # git identity (HM owns ~/.config/git/config)
│   ├── stylix.nix         # bridges Stylix palette → quickshell seed
│   ├── quickshell.nix     # installs the quickshell package
│   └── apps.nix           # cursor / GTK theme / icons / dark mode
│
├── templates/             # ★ project scaffolds: `nix flake init -t .#<name>`
│   ├── python/            #   python service: devShell + Nix image + justfile + manifests
│   ├── hugo/              #   hugo static site → nginx image + justfile + manifests
│   ├── react/             #   react (vite) build → nginx image + justfile + manifests
│   └── dev/               #   kitchen-sink devShell only (no image/deploy) — the default
│
├── labs/                  # opt-in experiments: k8s-telemetry (k3s + manifests), k8s-registry
│
└── modules/               # system + home modules (audio, bluetooth, amdgpu, …)
```

## Build & deploy

```bash
omni-apply      # alias: sudo nixos-rebuild switch --flake ~/.omni-nix#nixos-btw
```

Flakes evaluate from the **git index** — `git add` any new/changed file before rebuilding, or it's invisible to the build. Use `sudo nixos-rebuild dry-activate --flake .#nixos-btw` to test without switching.

---

## ★ Tracking a new config file/folder

The declarative way to version-control an app's config. Deployed configs become **read-only Nix-store symlinks** at `~/.config/<app>` — you edit the file under `configs/` and rebuild; never edit `~/.config/<app>` directly. Three cases:

### Case A — a fully static config (the common case: fastfetch, rofi)

The app never writes to its config dir at runtime.

1. **Copy** the dir into the repo:
   ```bash
   cp -r ~/.config/<app> configs/<app>
   ```
2. **Wire** it in `home/dotfiles.nix`:
   ```nix
   xdg.configFile."<app>".source = ../configs/<app>;
   ```
3. **Build & push** using the flow below.

### Case B — a config dir that is WRITTEN TO at runtime (e.g. hypr)

Quickshell writes `~/.config/hypr/quickshell-colors.conf` on theme changes. A whole-dir `.source` would turn the dir into a read-only symlink and **break those writes**, so deploy **per-file** and leave the runtime file unmanaged:

1. **Copy only the static files** into `configs/<app>/` — exclude the runtime-written file(s).
2. **Wire per-file** in `home/dotfiles.nix` — copy the existing `hyprStaticFiles` list + `builtins.listToAttrs` pattern. The dir stays a real, writable directory.
3. **Build & push.**

### Case C — a separate, actively-developed git project (e.g. quickshell)

Do **not** ingest it. Keep it as its own repo so you keep the edit → hot-reload dev loop, and back it up to its own GitHub remote (see *Two repos*).

### The build & push flow (every time)

```bash
git add configs/<app> home/dotfiles.nix                  # 1. stage (flakes read the git index)
sudo nixos-rebuild dry-activate --flake .#nixos-btw      # 2. confirm a clean build
omni-apply                                                # 3. apply
ls -l ~/.config/<app>                                     # 4. verify it's now a store symlink
rm -rf ~/.config/<app>.backup                             # 5. remove the HM backup once verified
git commit -m "feat(dots): ingest <app> config"          # 6. commit + push
git push
```

### Gotchas

- **`git add` before rebuild** — a new `.nix` or anything under `configs/` is invisible to the build until staged.
- **Only static configs go as whole-dir sources.** Runtime-written dirs must be per-file (Case B), or the app's writes silently fail.
- **HM backs up** an existing live `~/.config/<app>` to `<app>.backup` on first deploy (`backupFileExtension = "backup"`) — remove it once you've verified the symlink.
- **Edit `configs/`, never `~/.config/<app>`** — the live path is a symlink into the read-only store.
- **Re-login** for session/env changes to take effect.

---

## Adding packages & services (not configs)

- **System service / module** (needs root, drivers, kernel): create under `modules/`, import it in `hosts/desktop/default.nix`.
- **User package** (no config needed): add to `home.packages` in `home/apps.nix` or `modules/apps/essentials.nix`.
- **Language toolchains (node, python, hugo, tailwind, …): NOT global.** Put them in a per-project flake — see *Development environments* below.
- Search packages at <https://search.nixos.org>.

---

## 🧑‍💻 Development environments (per-project shells)

> **Full guide: [`DEV-ENVIRONMENTS.md`](DEV-ENVIRONMENTS.md)** — migrate existing Python / React / Hugo projects and start new ones, step by step.

Language toolchains are **not installed globally** — that's what broke things after the Arch migration (read-only store → PEP-668 pip errors, npm-global hacks, one version per language). Instead each project declares its own tools in a `flake.nix`, and `direnv` auto-loads them on `cd`. The system and `~/.config` stay clean. This is wired by `home/devshell.nix` (direnv + nix-direnv).

### Create a NEW project

Pick the template that matches the stack — `#python`/`#react`/`#hugo` each ship a devShell **plus** a Nix-built container image and a `justfile` for build → push → k8s deploy (`#dev` is a kitchen-sink devShell only):

```bash
mkdir my-app && cd my-app && git init
nix flake init -t ~/.omni-nix#python    # or #react / #hugo / #dev
git add flake.nix .envrc justfile app manifests   # flakes read the git index
direnv allow                            # one-time: trust the devShell
```

The stack's tools are now on `$PATH` (auto-loaded by direnv). Tailor `flake.nix` (image name, deps), `justfile` (`image`/`tag`/`ns`/`dep`), and `manifests/` to the project, then `direnv allow` again.

### Build & deploy to k8s (Python / Hugo / React templates)

These templates build a **reproducible OCI image with Nix** (no Dockerfile) and deploy it to the local k3s cluster. From the project dir, with k3s up (`sudo systemctl start k3s` — it's on-demand):

```bash
just build      # nix build .#image  →  ./result (image tarball)
just push       # skopeo → localhost:5000/<app>:latest  (no docker in the loop)
just deploy     # kubectl apply manifests + rollout restart
just logs       # tail the pod
just forward    # port-forward :8080 → curl localhost:8080
```

Prerequisites, all wired by this repo: a k3s single-node cluster (`labs/k8s-telemetry/nix/k3s.nix`), a local registry on `127.0.0.1:5000` (`labs/k8s-registry.nix`), and `just` + `skopeo` globally (`modules/apps/dev-tools.nix`). The lab pyapp at `labs/k8s-telemetry/python-app/` is the live reference for this flow.

### Add a devShell to an EXISTING project

```bash
cd path/to/existing-project
nix flake init -t ~/.omni-nix#dev      # scaffolds flake.nix + .envrc (no overwrites if they exist)
direnv allow                            # trust + load the shell
```

Then trim `flake.nix` to just the tools that project needs and re-run `direnv allow`. Commit `flake.nix`, `flake.lock`, and `.envrc`; the `.direnv/` cache stays gitignored.

### Everyday use

| Action | Command |
|---|---|
| Enter project | `cd project/` → tools auto-load (instant, cached) |
| Leave project | `cd ..` → tools auto-unload |
| After editing `flake.nix` | `direnv allow` (re-evaluates) |
| Force a clean reload | `direnv reload` |
| Manual entry (no direnv) | `nix develop` |

### Python — the one rule that matters

Never `pip install` against Nix's Python (read-only → PEP-668). Use `uv` inside the shell:

```bash
uv venv && source .venv/bin/activate
uv pip install -r requirements.txt   # or: uv sync  (with pyproject.toml)
```

The interpreter comes from Nix; deps + venv come from `uv`. Best of both.

### Note after the first rebuild

The first time you run `omni-apply` with these changes, `node`/`python`/`hugo`/`tailwindcss` leave the global `$PATH`. They reappear the moment you `cd` into any project that has a `flake.nix` (existing ones get one via the steps above). Nothing is lost — just scoped.

## Secrets

Secrets live **out of tree** at `~/.config/secrets/` (gitignored) and are injected by activation scripts — never committed. Example: `ANTHROPIC_AUTH_TOKEN` is read from `~/.config/secrets/zai_key` and written to `~/.claude/settings.json` by the `configure-claude` activation script. Never put a literal secret in a tracked `.nix` file.

## Cloning to a fresh machine

```bash
git clone git@github.com:ngeran/omni-dots.git   ~/.omni-nix
git clone git@github.com:ngeran/velocity.git    ~/.config/quickshell   # the desktop shell
sudo nixos-rebuild switch --flake ~/.omni-nix#nixos-btw
```

Then restore `~/.config/secrets/` (out of tree) — `wallpaper.jpg` ships in the repo, so Stylix regenerates its palette automatically on first build.
