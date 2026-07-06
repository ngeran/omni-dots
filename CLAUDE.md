# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A NixOS + Home Manager **flake** that defines a single machine, `nixos-btw` (x86_64-linux, NixOS 26.05, AMD CPU/GPU desktop). It installs the OS, packages, services, and seeds theme files — but the actual desktop shell is **not** here.

**Two-repo split — understand this before editing:**
- `~/.omni-nix/` (this repo) — the Nix flake. Declares system + home config and installs Quickshell as a package.
- `~/.config/quickshell/` — a **separate git repository** holding the QML desktop shell (bar, settings dashboard, login screen). It has its own `CLAUDE.md` and `MEMORY.md`. Edit QML there, not here. This repo only installs `quickshell` and bridges theme files into `~/.config/quickshell/`.

The `README.md` is partly stale (e.g. it describes an `omni-apply` script file that does not exist, and lists files that have since moved). Trust the code over the README.

## Build & deploy

```bash
omni-apply        # = sudo nixos-rebuild switch --flake ~/.omni-nix/#nixos-btw  (bash alias, defined in home/default.nix)
omni-apply        # first time after adding/changing any .nix file you MUST `git add` it first (see below)
```

- **Flakes evaluate from the git index.** A new or modified `.nix` file is invisible to the build until `git add`-ed. Forgetting this is the #1 cause of "my change did nothing."
- There are no tests, lint, or build steps beyond `nixos-rebuild`. `nixos-rebuild build` dry-runs a generation without switching; `nixos-rebuild test` applies without making it the boot default.
- To check evaluation without sudo: `nix flake check` (may surface unrelated warnings) or `nix build .#nixosConfigurations.nixos-btw.config.system.build.toplevel`.

## Architecture: three layers + a module pool

`flake.nix` assembles one `nixosConfigurations.nixos-btw` from three layers. Hardware comes from `nixos-hardware` (common-cpu-amd, common-gpu-amd, common-pc-ssd).

1. **`core/default.nix`** — base system imported at the flake top level: bootloader, timezone, networking, nix settings (flakes + auto-optimise + weekly GC), the `nikos` user, `system.stateVersion`.
2. **`hosts/desktop/`** — this machine's hardware and compositor layer. `hosts/desktop/default.nix` is the wiring hub: it imports `hardware-configuration.nix` (generated, mostly hands-off) plus the **system-level** modules, and sets up Hyprland, XDG portals, nix-ld, and mount points. **Add a new system service/module by importing it here.**
3. **`home/`** — Home Manager config for user `nikos`. `home/default.nix` is the wiring hub: it imports `home/quickshell.nix`, `home/stylix.nix`, and the **home-level** modules under `modules/apps/`. **Add a new user-space package/module by importing it here.**

**`modules/`** is the shared pool, split by which layer consumes them:
- System modules (imported in `hosts/desktop/default.nix`): `audio.nix` (PipeWire+WirePlumber), `bluetooth.nix`, `amdgpu-compute.nix` (ROCm/Ollama), `virtualization.nix` (libvirt+docker), `greetd.nix` (tuigreet → `start-hyprland`), `file-manager.nix` (Thunar), `stylix.nix`, `fonts.nix`, `apps/desktop-apps.nix`, `apps/dev-tools.nix`.
- Home modules (imported in `home/default.nix`): `apps/essentials.nix`, `apps/programming.nix`, `apps/nixvim/default.nix`.

**Orphaned files (not imported anywhere, safe to ignore or delete):** `home/apps.nix`, `home/rofi.nix`. Their GTK/cursor and rofi config are superseded elsewhere or unused.

## The theming pipeline (most non-obvious part)

Wallpaper → color palette → live desktop theme flows through three files across two repos. Do not collapse these into one — each is a specific read/write boundary:

1. **`modules/stylix.nix`** — [Stylix](https://stylix.danth.me/) generates a base16 palette **at build time** from `wallpaper.jpg`. It runs in **palette-only mode** (`autoEnable = false`) so it does NOT theme apps itself (that would fight Quickshell's live theming). It also installs the `qs-apply-wallpaper` helper (see below). matugen was removed — nixpkgs matugen 4.0.0 cannot decode images.
2. **`home/stylix.nix`** — bridges Stylix's palette into a **read-only seed** at `~/.config/quickshell/stylix-palette.json` (a `home.file` symlink into the nix store). This is a SEED only — regenerated every rebuild from the current wallpaper.
3. **`~/.cache/theme/colors.json`** — the **live, writable** theme channel. The Quickshell settings process writes it on every theme change; the bar watches it via FileView. Seeded once (only if absent) by an activation script in `modules/apps/essentials.nix` (`seedThemeColors`).

**Why colors.json is an activation script and not `home.file`:** `home.file` symlinks the target read-only into the nix store, which silently broke live theme switching (the settings process's write failed, so the file never changed and the bar's FileView never fired). Keep colors.json writable — never convert it to `home.file`.

**Changing the wallpaper:** `qs-apply-wallpaper <image>` (system package from `modules/stylix.nix`) copies the image into the flake tree as `wallpaper.jpg`, then rebuilds so Stylix regenerates the palette. The Quickshell dashboard runs it via `pkexec`. A **passwordless polkit rule** (`security.polkit.extraConfig` in `modules/stylix.nix`) pre-authorizes this one action for members of `wheel`, so APPLY WALLPAPER runs with no prompt — no GUI auth agent needed (none ships with the Quickshell/Hyprland setup). The rule matches by binary basename (`/qs-apply-wallpaper`) because polkit canonicalizes the program path through the symlink to the resolved store path, so matching the exact symlink never hits. Paths inside the script are hardcoded to `/home/nikos` because pkexec runs as root.

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
- `home-manager` uses `useGlobalPkgs` + `useUserPackages`, with `backupFileExtension = "backup"` (conflicting home files get `.backup` suffixes instead of blocking the switch).
- `wallpaper.jpg` is a large binary (~685 KB) committed directly to the repo and is the Stylix palette source. Edit by replacing the file, not by editing in place.
