{ ... }:

{
  # Git identity + config. Home Manager owns ~/.config/git/config as a read-only
  # store symlink, so imperative `git config --global` fails ("Read-only file
  # system"). Edit this block and `omni-apply` instead — never git config --global.
  programs.git = {
    enable = true;

    # HM folded userName/userEmail/extraConfig into one `settings` attrset (the
    # old names still work but emit evaluation warnings). `settings` maps 1:1
    # onto git config sections: settings.user -> [user], settings.core -> [core]…
    settings = {
      user = {
        name = "ngeran";
        email = "ngeran@gmail.com";
      };
      core.editor = "nvim";
      github.user = "ngeran";
      init.defaultBranch = "main";   # default branch for new (and this) repo
      mergetool.prompt = false;
      pull.rebase = false;           # merge on pull — git's default, stated explicitly

      # ── delta pager wiring (binary installed by
      # modules/apps/ai-tools/git-delta.nix) ──────────────────────────────
      # Routes git diff/log/show/stash -p through delta: syntax-highlighted,
      # line-numbered diffs — for reviewing agent-written code at speed.
      # `n`/`N` then jump between files inside one diff (delta.navigate).
      core.pager = "delta";
      interactive.diffFilter = "delta --color-only";  # `git add -p` stays interactive
      delta.navigate = true;
      merge.conflictstyle = "diff3";                  # delta renders conflict markers best
    };
  };
}
