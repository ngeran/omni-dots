{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # CLI Utils
    fzf
    ripgrep
    fd
    git-lfs
    
    # Coding Stuff
    lua
    tailwindcss
    hugo
    
  ];
}
