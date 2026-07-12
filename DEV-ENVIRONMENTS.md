# Development Environments — migration & new-project guide

How to bring existing **Python / React (Next.js) / Hugo** projects onto the
Nix flake + direnv dev-shell workflow, and how to start fresh ones.

> **One-line summary:** every project gets its own `flake.nix` declaring the
> tools it needs; `direnv` auto-loads them on `cd`. Nothing is installed
> globally — the system and `~/.config` stay clean.

---

## How it works (30-second version)

- Language toolchains (node, python, hugo, tailwind) are **never** global.
- Each project ships a `flake.nix` with a `devShell` listing its tools.
- `direnv` loads that shell automatically when you `cd` in, and unloads on `cd` out.
- `nix-direnv` caches the evaluation, so loading is instant after the first time.

This is wired by [`home/devshell.nix`](home/devshell.nix) (direnv + nix-direnv).
A ready scaffold lives in the flake as the `dev` template.

## Prerequisites (already wired into this repo)

- `omni-apply` has been run (installs `direnv` + `nix-direnv`, bash hook).
- You've **logged out and back in** once (so the bash hook is active).
- The template is available: `nix flake init -t ~/.omni-nix#dev`.

## The two golden rules (breaking these = silent failure)

1. **`flake.nix` must be tracked by git** *inside every project repo*. Nix
   flakes evaluate from the git index — an untracked `flake.nix` is invisible
   and direnv silently falls back to your global PATH (no `python`/`node`).
   ```bash
   git add flake.nix .envrc          # stage in the project's own repo — no commit needed
   ```
2. **`direnv allow` after every edit** to `flake.nix` or `.envrc`. direnv
   blocks on a stale allow-hash until you re-allow.

## The universal pattern (all stacks)

```
1. scaffold   →  nix shell nixpkgs#<tool> -c <scaffold-cmd>   (borrow the tool once; nothing is global)
2. flake      →  nix flake init -t ~/.omni-nix#dev  +  tailor flake.nix to the project
3. activate   →  git add flake.nix .envrc && direnv allow
4. install/run →  the stack's own install/run command
```

---

# Migrating an EXISTING project

For each project: drop in a tailored `flake.nix` + `.envrc`, stage them,
`direnv allow`, then (re)install deps in the now-active shell.

## 🐍 Python  *(e.g. `biterrors` — FastAPI + Textual TUI)*

1. **Scaffold the devShell** in the project root:
   ```bash
   cd path/to/project
   nix flake init -t ~/.omni-nix#dev
   ```
2. **Tailor `flake.nix`** to Python only — keep `python3` + `uv`, delete
   `nodejs_22` / `pnpm` / `tailwindcss` / `hugo`:
   ```nix
   packages = with pkgs; [
     python3     # interpreter (deps come from the venv via uv, NOT system pip)
     uv          # venv + dependency manager

     # optional insurance for source builds (e.g. lxml from junos-eznc):
     libxml2
     libxslt
   ];
   ```
3. **Auto-activate the venv on cd** — replace `.envrc` with:
   ```bash
   use flake

   # Auto-activate the project venv once it exists.
   if [ -f .venv/bin/activate ]; then
     source .venv/bin/activate
   fi
   ```
4. **Activate:**
   ```bash
   git add flake.nix .envrc && direnv allow
   ```
5. **Recreate the venv** (the old one likely points at `/usr/bin/python3`,
   which does not exist on NixOS) and install deps:
   ```bash
   rm -rf .venv && uv venv
   uv pip install -e '.[dev]'        # project deps + optional [dev] extra
   ```

> ⚠️ **Never `pip install` against Nix's Python** — it's read-only (PEP-668).
> Always go through `uv` → the project's `.venv`.

## ⚛️ React / Next.js  *(e.g. `ggeran` — Next 16 / React 19 / Tailwind 4)*

1. **Scaffold + tailor `flake.nix`** to Node (+ `python3` for native addons
   like `bcrypt`; the C compiler is already in `mkShell`):
   ```bash
   cd path/to/project
   nix flake init -t ~/.omni-nix#dev
   ```
   ```nix
   packages = with pkgs; [
     nodejs_22   # Next.js runtime + bundled npm
     python3     # node-gyp fallback for native addons (bcrypt, etc.)
   ];
   ```
   `.envrc` stays the plain default:
   ```bash
   use flake
   ```
2. **Activate + install:**
   ```bash
   git add flake.nix .envrc && direnv allow
   npm install            # only if node_modules is missing or broken
   npm run dev
   ```

> An existing `node_modules/` from another distro usually still works on NixOS
> (verify with `node -e "require('next/package.json').version"`). If a native
> addon breaks after a Node bump: `npm rebuild` (or `rm -rf node_modules && npm install`).

## 🌐 Hugo  *(e.g. `ngeranio` — Hugo + Tailwind/PostCSS pipeline)*

1. **Scaffold + tailor `flake.nix`** to Hugo + Node (the asset pipeline):
   ```bash
   cd path/to/project
   nix flake init -t ~/.omni-nix#dev
   ```
   ```nix
   packages = with pkgs; [
     hugo        # nixpkgs ships the EXTENDED edition (SCSS / asset pipeline)
     nodejs_22   # Tailwind / PostCSS asset pipeline (npm install once)
   ];
   ```
   `.envrc` stays the plain default:
   ```bash
   use flake
   ```
2. **Activate + serve:**
   ```bash
   git add flake.nix .envrc && direnv allow
   npm install            # only if the asset pipeline's node_modules is missing
   hugo server -D         # → http://localhost:1313
   ```

> Theme submodules carry over unchanged — `git submodule update --init` if a
> theme dir is empty. nixpkgs `hugo` is the extended build, so SCSS/Tailwind
> pipelines work out of the box.

---

# Creating a NEW project

The tool you scaffold with isn't global, so **borrow it once** with
`nix shell nixpkgs#<tool> -c ...`; after that the flake owns it.

## 🐍 Python

```bash
# 1. scaffold (borrow uv):
nix shell nixpkgs#uv -c uv init my-py
cd my-py && git init

# 2. devShell + tailor (keep python3 + uv; delete node/hugo/tailwind):
nix flake init -t ~/.omni-nix#dev
$EDITOR flake.nix

# 3. activate:
git add flake.nix .envrc && direnv allow

# 4. deps + run (uv now from the flake):
uv venv && uv pip install rich requests
uv run python main.py
```

## ⚛️ React (Vite + TypeScript)

```bash
# 1. scaffold (borrow node):
nix shell nixpkgs#nodejs_22 -c npm create vite@latest my-app -- --template react-ts
cd my-app && git init

# 2. devShell + tailor (keep nodejs_22; delete hugo/python/tailwind):
nix flake init -t ~/.omni-nix#dev
$EDITOR flake.nix

# 3. activate (node now from the flake):
git add flake.nix .envrc && direnv allow

# 4. install + run:
npm install && npm run dev
```

**Next.js variant:** swap the scaffold for
`nix shell nixpkgs#nodejs_22 -c npx create-next-app@latest my-app`, and keep
`python3` in the flake (native addons like `bcrypt`).

## 🌐 Hugo

```bash
# 1. scaffold (borrow hugo):
nix shell nixpkgs#hugo -c hugo new site my-site
cd my-site && git init

# 2. devShell + tailor (keep hugo + nodejs_22; delete python/tailwind):
nix flake init -t ~/.omni-nix#dev
$EDITOR flake.nix

# 3. activate:
git add flake.nix .envrc && direnv allow

# 4. add a theme + serve:
git submodule add https://github.com/adityatelange/hugo-PaperMod themes/PaperMod
echo 'theme = "PaperMod"' >> hugo.toml
hugo server -D
```

---

# Everyday direnv

| Action | Command |
|---|---|
| Enter project (tools auto-load) | `cd project/` |
| Leave project (tools auto-unload) | `cd ..` |
| After editing `flake.nix` or `.envrc` | `direnv allow` |
| Force a clean reload | `direnv reload` |
| See what the shell added | `direnv status` |
| Enter without direnv | `nix develop` |

---

# Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `python3` / `node` "not found" inside the project | `flake.nix` not git-tracked → `git add flake.nix .envrc`, then `direnv allow`. Or the flake failed to eval — run `nix develop` to see the error. |
| `direnv: error .envrc is blocked` | You edited `.envrc` — re-run `direnv allow`. |
| `externally-managed-environment` (pip) | You ran system `pip`. Use `uv` → the project `.venv` (`uv pip install ...`). |
| Native node addon errors after a Node bump | `npm rebuild` (or `rm -rf node_modules && npm install`). |
| `EACCES` / global npm install | Never `npm install -g`. Add the tool to `flake.nix` `packages` instead. |
| Python version mismatch | The flake's `python3` is 3.13. Pin a specific one with `python311`, `python312`, etc. if a project requires it. |
| direnv never triggers | Bash hook not loaded — log out/in once after `omni-apply`, or open a new terminal. |

---

# What to commit (per project repo)

```bash
git add flake.nix flake.lock .envrc
```

- `flake.nix` + `flake.lock` → pin the exact toolchain (reproducibility).
- `.envrc` → the direnv trigger.
- `.venv/`, `node_modules/`, `.direnv/` → **never** commit (the template's
  `.gitignore` already excludes them).

The flake, lock, and `.envrc` travel with the project — anyone (or a fresh
clone) gets the identical environment with just `direnv allow`.
