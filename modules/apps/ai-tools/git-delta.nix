# =========================================================================
# AI TOOLS: git-delta — syntax-highlighted, side-by-side pager for git diffs
# =========================================================================
# Why: you will be REVIEWING far more code than you write — agents produce
# diffs at machine speed. Raw unified diffs do not scale; delta gives
# language-aware syntax highlighting, line numbers, and inline
# moved-line detection, which makes "is this AI edit actually correct?" a
# 5-second visual check instead of a squint.
#
# Two-part install (this file is only half of it):
#   1. HERE: the `delta` binary, system-wide.
#   2. home/git.nix: the git config that routes `git diff/log/show` through
#      delta (core.pager + interactive.diffFilter + navigate keybindings).
#      Kept in git.nix — not here — because git behavior is a HOME-layer
#      concern and git.nix is its single source of truth.
#
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    delta
  ];
}
