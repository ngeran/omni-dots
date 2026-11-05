# Global OpenCode Rules

## Workflow
- One task per session. Start a fresh session for a new task; PLAN.md carries
  state, not the chat history.
- Plan -> build -> review. Use the `plan` agent (Tab to switch) to write
  `PLAN.md`, then a fresh `build` session to execute only the requested steps.
- Each PLAN.md step must be small, independently verifiable, and include the
  command that proves it passed.
- After every step, run the project's check command. Tick the box only when it
  passes; fix failures before moving on.
- Run the `reviewer` subagent on the diff before committing.

## Rules
- Never invent APIs, NixOS options, CLI flags, or QML types. Verify in the repo,
  Context7, or upstream docs first; if you cannot confirm it, say so.
- Use the `explore` subagent for broad searches instead of reading whole
  directories into the main context.
- Prefer the smallest change that works and follow existing project patterns.
- Do not add dependencies or refactor unrelated code without asking.
- When creating or rewriting a file, deliver the complete file, not fragments.
- Never commit secrets. Secrets live in `~/.config/secrets/`.
- Do not run destructive commands (`rm -rf`, force-push, `nixos-rebuild switch`)
  without explicit approval.
