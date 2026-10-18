---
name: token-hygiene
description: Keep context small and stop token waste. Use at session start, when switching tasks, when context feels heavy, or when the user mentions tokens, cost, clear, compact, or efficiency.
---

# Token Hygiene

Context is the main cost driver. Keep it small, relevant, and fresh.

(RTK already filters tool output at hook level — this skill is the discipline hooks can't do: context shape and session boundaries.)

## Session habits

1. **New unrelated task → `/clear`**. Do not carry old history into a new problem.
2. **Same task but context is long → `/compact` with explicit keep instructions**, e.g.  
   `/compact Keep files changed, open acceptance criteria, failing tests, and the current plan. Drop exploratory reads and old command noise.`
3. Don't switch models mid-session — it breaks the prompt cache.

## Working with files

- Prefer `@exact/path` over vague searches. Read the smallest useful slice — a function or section, not a whole large file.
- Do not re-read a file already in context unless it may have changed.
- Delegate broad multi-file exploration to a subagent (Explore) so bulk reads stay out of the main thread.

## Scope

- Work in small slices. Finish and verify one logical step before expanding.
- Stop early (Esc) when heading the wrong direction.
