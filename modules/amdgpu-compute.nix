{ config, pkgs, ... }:

{
  # 1. Hardware & Driver Setup
  boot.initrd.kernelModules = [ "amdgpu" ];
  
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      rocmPackages.clr.icd      # OpenCL
      rocmPackages.rocm-runtime  # HIP/ROCm Core
    ];
  };

  # 2. Native Ollama Service (Updated for NixOS 26.05)
  services.ollama = {
    enable = true;
    # In 26.05, we choose the package directly instead of using the 'acceleration' toggle
    package = pkgs.ollama-rocm; 
    rocmOverrideGfx = "11.0.0"; # Still needed for your RX 7600
  };

  # 3. Global environment for OTHER compute apps
  environment.variables = {
    HSA_OVERRIDE_GFX_VERSION = "11.0.0";
    HCC_AMDGPU_TARGET = "gfx1101";
  };

  # 4. System Tools
  environment.systemPackages = with pkgs; [
    rocmPackages.rocm-smi
    rocmPackages.rocminfo
    clinfo
  ];
}
