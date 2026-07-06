# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A NixOS + Home Manager **flake** that defines a single machine, `nixos-btw` (x86_64-linux, NixOS 26.05, AMD CPU/GPU desktop). It installs the OS, packages, services, **ingests application configs** (fastfetch, rofi, hypr), and seeds theme files — but the actual desktop shell is **not** here.

**Two-repo split — understand this before editing:**
- `~/.omni-nix/` (this repo → **`github.com/ngeran/omni-dots`**) — the Nix flake. Declares system + home config, installs Quickshell as a package, and ingests app configs.
- `~/.config/quickshell/` (→ **`github.com/ngeran/velocity`**) — a separate git repo holding the QML desktop shell (bar, settings dashboard, login screen). It has its own `CLAUDE.md` and `MEMORY.md`. **Edit QML there, not here.**

**Why quickshell stays a separate repo (do NOT fold it into this flake):** it's actively edited in place (edit → Quickshell hot-reloads), and `~/.config/quickshell/` is a *hybrid* directory — static QML + an HM-managed seed (`stylix-palette.json`) + files Quickshell writes at runtime (`theme-active.json`, `wallpaper-config.json`, …). A read-only store symlink would break the dev loop and those writes. This flake only installs the `quickshell` package and bridges the theme seed into that dir.

`README.md` is accurate and documents the config-ingestion workflow + fresh-machine bootstrap — keep it in sync when you change the ingestion pattern.

## Build & deploy

```bash
omni-apply      # alias (defined in home/default.nix): sudo nixos-rebuild switch --flake ~/.omni-nix#nixos-btw
```

- **Flakes evaluate from the git index.** A new or modified `.nix` file — or anything under `configs/` — is invisible to the build until `git add`-ed. This is the #1 cause of "my change did nothing."
- **The home directory is NOT a git repository.** It once was, and it leaked an entire browser profile to GitHub (committed `~/.config/chromium/` → cookies, passwords). It was abandoned. **Always scope git to a specific repo** (`git -C ~/.omni-nix …`), never bare `git …` from `~`. Never commit cache, browser profiles, shell history, or `~/.config/chromium` / `~/.cache`.
- No tests/lint beyond `nixos-rebuild`. `nixos-rebuild dry-activate` tests without switching; `nix build .#nixosConfigurations.nixos-btw.config.system.build.toplevel` checks evaluation without sudo.

## Architecture: three layers + a module pool

`flake.nix` assembles one `nixosConfigurations.nixos-btw` from three layers. Hardware comes from `nixos-hardware` (common-cpu-amd, common-gpu-amd, common-pc-ssd).

1. **`core/default.nix`** — base system imported at the flake top level: bootloader, timezone, networking, nix settings (flakes + auto-optimise + weekly GC), the `nikos` user, `system.stateVersion`.
2. **`hosts/desktop/`** — this machine's hardware + compositor layer. `hosts/desktop/default.nix` is the wiring hub: it imports `hardware-configuration.nix` (generated, mostly hands-off) plus the **system-level** modules, and sets up Hyprland, XDG portals, nix-ld, and mount points. **Add a new system service/module by importing it here.**
3. **`home/`** — Home Manager config for user `nikos`. `home/default.nix` is the wiring hub: it imports the home-level siblings (`apps.nix`, `quickshell.nix`, `stylix.nix`, `git.nix`, `dotfiles.nix`) and the home modules under `modules/apps/` (`essentials.nix`, `programming.nix`, `nixvim/default.nix`). **Add a new user-space module by importing it here.**

**`modules/`** — shared pool, split by which layer consumes them:
- System modules (imported in `hosts/desktop/default.nix`): `audio.nix` (PipeWire+WirePlumber), `bluetooth.nix`, `amdgpu-compute.nix` (ROCm/Ollama), `virtualization.nix` (libvirt+docker), `greetd.nix` (tuigreet → `start-hyprland`), `file-manager.nix` (Thunar), `stylix.nix`, `fonts.nix`, `apps/desktop-apps.nix`, `apps/dev-tools.nix`.

**Home-level modules (siblings under `home/`):**
- `apps.nix` — cursor (`home.pointerCursor`, Bibata), GTK theme/icon-theme/cursor-theme, Qt platform theme, and dark mode (`dconf org/gnome/desktop/interface color-scheme = prefer-dark`). *Previously listed as orphaned — it is now imported and is what fixed cursor/icons/dark-mode.*
- `git.nix` — git identity via `programs.git.settings`. HM owns `~/.config/git/config` as a read-only store symlink, so **`git config --global` fails by design** ("Read-only file system"). Edit `home/git.nix` and rebuild instead.
- `dotfiles.nix` — the ingested-configs hub (see below).
- `stylix.nix` / `quickshell.nix` — theme seed bridge / installs the quickshell package.

**Orphaned (not imported; safe to delete):** `home/rofi.nix` — superseded by `configs/rofi` + `dotfiles.nix`.

## Ingested application configs (`configs/` + `home/dotfiles.nix`)

fastfetch, rofi, and hypr configs are version-controlled by **ingesting** them: checked-in trees under `configs/` deployed to `~/.config/<app>` by `home/dotfiles.nix` via `xdg.configFile`. They become **read-only Nix-store symlinks** — edit the file under `configs/` and rebuild; never edit `~/.config/<app>` directly.

**Two cases — get this right or you break runtime writes:**
- **Static config dir** (fastfetch, rofi) → whole-dir source: `xdg.configFile."<app>".source = ../configs/<app>;`
- **Dir written to at runtime** (hypr — Quickshell writes `~/.config/hypr/quickshell-colors.conf` on theme changes) → deploy **per-file** (see the `hyprStaticFiles` list + `builtins.listToAttrs` pattern in `dotfiles.nix`) so `~/.config/hypr/` stays a real, writable directory; leave `quickshell-colors.conf` unmanaged. A whole-dir source would make the dir read-only and silently break the writes — same class of bug as `colors.json` below.

The full add-a-config workflow (copy → wire → dry-activate → `omni-apply` → verify → clean `.backup` → commit/push) is in `README.md` → "Tracking a new config file/folder".

## The theming pipeline (most non-obvious part)

Wallpaper → color palette → live desktop theme flows through three files across two repos. Do not collapse these into one — each is a specific read/write boundary:

1. **`modules/stylix.nix`** — [Stylix](https://stylix.danth.me/) generates a base16 palette **at build time** from `wallpaper.jpg`. It runs in **palette-only mode** (`autoEnable = false`) so it does NOT theme apps itself (that would fight Quickshell's live theming). It also installs the `qs-apply-wallpaper` helper (see below). matugen was removed — nixpkgs matugen 4.0.0 cannot decode images.
2. **`home/stylix.nix`** — bridges Stylix's palette into a **read-only seed** at `~/.config/quickshell/stylix-palette.json` (a `home.file` symlink into the nix store). This is a SEED only — regenerated every rebuild from the current wallpaper.
3. **`~/.cache/theme/colors.json`** — the **live, writable** theme channel. The Quickshell settings process writes it on every theme change; the bar watches it via FileView. Seeded once (only if absent) by an activation script in `modules/apps/essentials.nix` (`seedThemeColors`).

**Why colors.json is an activation script and not `home.file`:** `home.file` symlinks the target read-only into the nix store, which silently broke live theme switching (the settings process's write failed, so the file never changed and the bar's FileView never fired). Keep colors.json writable — never convert it to `home.file`.

**Changing the wallpaper:** `qs-apply-wallpaper <image>` (system package from `modules/stylix.nix`) copies the image into the flake tree as `wallpaper.jpg`, then rebuilds so Stylix regenerates the palette. The Quickshell dashboard runs it via `pkexec` (polkit GUI prompt) — no standing sudo rule, no sudoers entry. Paths inside are hardcoded to `/home/nikos` because pkexec runs as root.

## Secrets pattern

Secrets are **out of tree** at `~/.config/secrets/` (gitignored). They are injected at activation time, never committed.

- **Claude Code / z.ai gateway** is the canonical example. The flake routes Claude Code through a **z.ai Anthropic-compatible gateway** (`ANTHROPIC_BASE_URL = https://api.z.ai/api/anthropic`), with models remapped (`glm-4.7`, `glm-5.2[1m]`). `ANTHROPIC_AUTH_TOKEN` is read from `~/.config/secrets/zai_key` and written into `~/.claude/settings.json` by the `configure-claude` activation script in `modules/apps/essentials.nix`.
- **Do not manage `~/.claude/settings.json` with `home.file`.** It collides with the activation script: each switch would leave a real file that home-manager then tries to back up, and the accumulating `.backup` files eventually block switches ("would be clobbered"). The activation script is the sole writer. `programming.nix` sets `ANTHROPIC_AUTH_TOKEN_FILE` as an env fallback instead.

When adding a new secret: store the raw value in `~/.config/secrets/<name>`, read it from an activation script (`lib.hm.dag.entryAfter ["writeBoundary"]`), and never reference the literal in a tracked `.nix` file.

## Hardware specifics baked into the config

- **AMD RX 7600 (gfx1101 / RDNA3):** ROCm needs `rocmOverrideGfx = "11.0.0"` + `HSA_OVERRIDE_GFX_VERSION=11.0.0` (in `modules/amdgpu-compute.nix`). Ollama uses `ollama-rocm`.
- **Wi-Fi/Bluetooth:** MediaTek MT7922/MT7921 module — `mt7922` is force-loaded in `modules/bluetooth.nix`.
- **Mounts** (`hosts/desktop/default.nix`): `/mnt/DATA-2T` (ext4), `/mnt/SSD-250` (ntfs), plus bind mounts mapping nvim state dirs onto `/persist` for persistence across reboots.

## Version pins & gotchas

- All inputs track **release-26.05** except **nixvim**, which uses `main` for 26.05 compatibility. Its nixpkgs release-version check is disabled (`version.enableNixpkgsReleaseCheck = false`) and `nixpkgs.source` is pinned to the flake input to silence `follows` warnings — see `modules/apps/nixvim/default.nix`.
- `home-manager` uses `useGlobalPkgs` + `useUserPackages`, with `backupFileExtension = "backup"` (conflicting home files get `.backup` suffixes instead of blocking the switch). When you ingest a new config, HM moves the existing live `~/.config/<app>` to `<app>.backup` on first deploy — remove it after verifying the symlink.
- `wallpaper.jpg` is a large binary (~685 KB) committed directly to the repo and is the Stylix palette source. Edit by replacing the file, not by editing in place.
