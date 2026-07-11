# davinci.nix
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # The standard free version. 
    # Use 'davinci-resolve-studio' here if you have a paid license key.
    davinci-resolve 
  ];

  # DaVinci Resolve needs specific environment variables to run well on NixOS/AMD
  home.sessionVariables = {
    # Helps with UI scaling on high-res monitors
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    
    # Force DaVinci to use the AMD OpenCL backend
    # This is often needed if it doesn't auto-detect the 7600 XT
    ROC_ENABLE_PRE_VEGA = "0"; 
  };
}
