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
    };
  };
}
