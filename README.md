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
│   ├── git.nix            # git identity (HM owns ~/.config/git/config)
│   ├── stylix.nix         # bridges Stylix palette → quickshell seed
│   ├── quickshell.nix     # installs the quickshell package
│   └── apps.nix           # cursor / GTK theme / icons / dark mode
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
- Search packages at <https://search.nixos.org>.

## Secrets

Secrets live **out of tree** at `~/.config/secrets/` (gitignored) and are injected by activation scripts — never committed. Example: `ANTHROPIC_AUTH_TOKEN` is read from `~/.config/secrets/zai_key` and written to `~/.claude/settings.json` by the `configure-claude` activation script. Never put a literal secret in a tracked `.nix` file.

## Cloning to a fresh machine

```bash
git clone git@github.com:ngeran/omni-dots.git   ~/.omni-nix
git clone git@github.com:ngeran/velocity.git    ~/.config/quickshell   # the desktop shell
sudo nixos-rebuild switch --flake ~/.omni-nix#nixos-btw
```

Then restore `~/.config/secrets/` (out of tree) — `wallpaper.jpg` ships in the repo, so Stylix regenerates its palette automatically on first build.
