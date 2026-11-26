# PLAN — Starship prompt: show which machine you are on

Status: **steps done (2026-11-26)** — built and rendered; waiting for the
user's `omni-apply`.
Date: 2026-11-26
Session scope: the starship block of `modules/apps/essentials.nix` only.
The previous plan in this file (k8s-lab Phase 1) is complete and stays in git
history: `git show 401989c:PLAN.md`.

## Context

The same user (`nikos`) and the same prompt are on every machine: this
desktop (`nixos-btw`, the only host this flake manages), the Omarchy laptop,
the Mac mini. Over ssh nothing in the prompt says which machine will run the
command.

Root cause: `modules/apps/essentials.nix` sets an explicit top-level starship
`format`. An explicit `format` replaces starship's whole default prompt and
this one does not list `$hostname`, so the `hostname` module is never drawn.

Found on the way: the `git_status` glyphs for `conflicted`, `up_to_date` and
`modified` are plain spaces in the Nix file, so a modified file shows no
marker. Upstream Omarchy has Nerd Font icons there.

## Decision log

- **Hostname display (user, 2026-11-26):** "Only inside SSH sessions" →
  `hostname.ssh_only = true`. The local prompt stays exactly as it is.
- **Git-status icons (user, 2026-11-26):** "Yes, restore them" → the three
  glyphs are copied byte-for-byte from upstream Omarchy in the same edit.
- **Known limitation (accepted):** `ssh_only` keys off the `SSH_CONNECTION` /
  `SSH_CLIENT` / `SSH_TTY` environment variables. A shell without them (for
  example a tmux pane started outside the ssh session) shows no label.
- **Right prompt rejected:** `right_format` is only drawn by starship's bash
  integration when ble.sh is attached, which this setup does not use.

## Locked decisions

| Decision | Choice |
|---|---|
| Module | starship `hostname`, placed in front of the existing top-level `format` |
| `hostname.ssh_only` | `true` |
| `hostname.format` | `"[$ssh_symbol$hostname]($style) "` (no `in`, trailing space) |
| `hostname.style` | `"bold yellow"` |
| Other machines | out of scope for the flake. The remote machine draws the prompt, so each device needs the same edit by hand in its own `~/.config/starship.toml` |

## Conventions

- Only `modules/apps/essentials.nix` changes, in the file's own style
  (2-space indent, short why-comments).
- The flake reads the git index: `git add` before any check.
- Evaluation only, no sudo, no switch. The user runs `omni-apply`.

## Steps

### 1. Add the hostname module, restore the git-status glyphs (`modules/apps/essentials.nix`)

- Prefix the top-level `format` with `$hostname`; add the `hostname` block.
- Copy `conflicted`, `up_to_date`, `modified` from upstream Omarchy byte for byte.
- Check: `nix-instantiate --parse modules/apps/essentials.nix > /dev/null && echo PARSE_OK`
- [x] parse OK; `git diff --stat` lists only `PLAN.md` and `modules/apps/essentials.nix`

### 2. Evaluate the flake and render the generated config

- Check: `git add PLAN.md modules/apps/essentials.nix && nix build .#nixosConfigurations.nixos-btw.config.system.build.toplevel`
- [x] build succeeds
- Check: render the generated `starship.toml` from the built `home-manager-files`
  with `starship prompt`, with and without `SSH_CONNECTION`
- [x] local prompt identical to the current one (also inside a git repo); under
  `SSH_CONNECTION` it starts with `🌐 nixos-btw`; no stderr warnings; the three
  glyphs match upstream bytes

## After the plan (user)

- `omni-apply`, then `ssh` somewhere and confirm the label.
- Laptop / Mac mini: the same edit by hand in `~/.config/starship.toml`.
