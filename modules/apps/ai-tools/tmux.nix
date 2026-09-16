# =========================================================================
# AI TOOLS: tmux — terminal multiplexer (sessions outlive terminals)
# =========================================================================
# Why it matters for agent work specifically: agent runs are LONG (minutes to
# hours) and often unattended. A tmux session survives a closed terminal, an
# ssh drop, or a compositor restart — detach, walk away, reattach later and
# the agent is still running:
#     tmux new -s codetest      # start work inside a named session
#     <C-Space> d               # detach (session keeps running)
#     tmux attach -t codetest   # reattach from anywhere
#
# CONFIG: ingested at configs/tmux/tmux.conf (deployed read-only by
# home/dotfiles.nix) — vi copy mode, prefixless Alt-pane/window controls,
# 50k scrollback. THEMED like ghostty: Quickshell's ThemeService rewrites
# ~/.cache/theme/tmux.conf on every theme change and hot-applies it, so the
# status bar / borders / copy-mode colors follow the active desktop theme.
#
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    tmux
  ];

  # Ship the full terminfo set system-wide. Inside tmux, TERM becomes
  # "tmux-256color" — an entry the tmux package provides but the base system
  # profile does NOT merge in by default. Without it, ncurses apps launched
  # from a tmux pane (nvim, htop, less) fall back to degraded rendering, and
  # ghostty-side integration misbehaves. This flag is the designed NixOS fix.
  environment.enableAllTerminfo = true;
}
