# =========================================================================
# AI TOOLS: tmux — terminal multiplexer (sessions outlive terminals)
# =========================================================================
# Why it matters for agent work specifically: agent runs are LONG (minutes to
# hours) and often unattended. A tmux session survives a closed terminal, an
# ssh drop, or a compositor restart — detach, walk away, reattach later and
# the agent is still running:
#     tmux new -s codetest      # start work inside a named session
#     <C-b> d                   # detach (session keeps running)
#     tmux attach -t codetest   # reattach from anywhere
#
# Bonus: split panes let you tail logs / watch `curl | jq` probes in one pane
# while an agent works in another.
#
# Bare install on purpose — the default keybindings are fine and a config
# file can be added later if a workflow needs it (ingest under configs/ then).
#
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    tmux
  ];
}
