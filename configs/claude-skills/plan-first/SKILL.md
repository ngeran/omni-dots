---
name: plan-first
description: Force structured planning before any non-trivial implementation. Use when starting a feature, bugfix, refactor, or multi-file change, or when the user says plan, design, implement, build, fix, or improve something that is not a one-line change.
---

# Plan-First Workflow

You MUST follow this process for any task that is not a trivial one-line fix.

## Hard rules

1. Do **not** edit files or run write commands until a plan exists and the user has approved it (or explicitly said "skip plan" / "just do it").
2. Prefer Plan Mode. If already in a normal session, still produce the plan first and wait for approval.
3. Keep the plan short and concrete. Name exact files. Prefer the smallest change that satisfies acceptance criteria.

## Required steps

### 1. Clarify acceptance criteria (if missing)

If the user did not give clear success criteria, ask for or propose:

- What the user should see / be able to do when done
- What is explicitly out of scope
- Any constraints (performance, compatibility, style, tests)

Write them as a short bullet list before planning.

### 2. Explore (read-only)

- Prefer targeted reads over broad searches. Identify existing patterns in the codebase and reuse them.
- Note risks, unknowns, and files that will change.
- **Flake gotcha:** flakes evaluate from the git index. A new or modified `.nix` file — or anything under `configs/` — is invisible to the build until `git add`-ed. When the plan adds files, include the `git add` step.

### 3. Produce the plan

Output a plan in this exact shape:

```markdown
## Goal
One sentence.

## Acceptance criteria
- [ ] ...

## Files to touch
- `path/to/file` — why

## Steps
1. ...
2. ...

## Tests / verification
- How we will know it works (commands, checks, expected output)

## Out of scope
- ...

## Risks / open questions
- ...
```

### 4. Stop and wait

After the plan, stop. Do not implement until the user approves, edits, or says to proceed.

If the user edits the plan, treat the edited version as authoritative.

## Verification planning for NixOS changes

When the change touches the flake (`~/.omni-nix`), the plan's Tests section must name the tier:

- **Evaluation only** (no sudo): `nix build .#nixosConfigurations.nixos-btw.config.system.build.toplevel`
- **Test without switching**: `nixos-rebuild dry-activate`
- **Apply**: the user runs `omni-apply` themselves — propose it, never run it for them.

## When you may skip the full plan

Only when **all** of these are true:

- The change can be described in one sentence
- It touches one file (or is a pure rename/move with no logic change)
- The risk of being wrong is near zero

Even then, state the one-sentence plan briefly before editing.
