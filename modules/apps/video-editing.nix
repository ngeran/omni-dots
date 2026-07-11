{ pkgs, ... }: {

  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [

     # Video Editing
     davinci-resolve

  ];
}
