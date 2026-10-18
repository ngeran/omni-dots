---
name: verify-work
description: Verify that changes actually work before claiming done. Use after implementing a feature or fix, before saying finished, when the user asks to test, check, verify, or confirm, or when finishing any non-trivial task.
---

# Verify Work

Never claim a task is complete without evidence.

## Required verification loop

1. **Restate what was changed** in 1–3 bullets (files + intent).
2. **Run the relevant checks**. Prefer the smallest useful command.
3. **Show the actual output** (or the relevant failure/success lines). Do not paraphrase "tests passed" without evidence.
4. **If anything fails**, fix it and re-run. Do not move on with failing checks unless the user explicitly accepts the failure.
5. **Map results back to acceptance criteria**. Every criterion must be checked or explicitly marked as not automated (and how it was verified manually).

## Verification commands for this system

Nix flake changes (`~/.omni-nix`):

- **Evaluation only** (no sudo, safe to run directly): `nix build .#nixosConfigurations.nixos-btw.config.system.build.toplevel`
- **Test without switching** (user runs): `nixos-rebuild dry-activate`
- **Apply** (user runs `omni-apply`): after switching, verify store symlinks landed (`ls -la` the deployed paths) and clean any stray `.backup` files.

Other repos on this machine:

- Git is always scoped: `git -C ~/.omni-nix …` / `git -C ~/.config/quickshell …` — never bare `git` from `~`.
- velocity repo auto-commits: check `git -C ~/.config/quickshell log` before assuming edits are uncommitted.
- Quickshell verification: use `log.qslog` + the user's eyes — strace is blocked (ptrace_scope=1), ps sampling proves nothing.

## Output format when finishing

```markdown
## Changes
- ...

## Verification
- Command: `...`
- Result: (paste key output)

## Acceptance criteria
- [x] ...
- [ ] ... (why not automated / how checked)
```

## Token hygiene while verifying

RTK already filters tool output at hook level — but still don't dump full logs into the conversation when a short excerpt is enough. Show the key lines.
