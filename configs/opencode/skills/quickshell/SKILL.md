---
name: quickshell
description: Quickshell QML bar widgets, plugins, and shell components. Load for any .qml file or Quickshell IPC/service/log task.
---

## Rules
- Quickshell APIs are niche and models hallucinate them. Before using any type
  (PanelWindow, Variants, Process, SystemClock, Pipewire, etc.), grep the
  existing config for a working usage, or check https://quickshell.org/docs.
  Do not guess.
- Keep one component per file; shared colors/sizes live in one singleton.
- Reuse the existing design tokens in the repo. Never hardcode new colors.
- Verify by restarting quickshell and reading its log output for QML errors
  before reporting done.
- Put polling in `Process` / `SplitParser` with sane intervals, not tight
  timers.
