{ config, lib, pkgs, ... }:

# hashcat 7.1.2 — GPU-accelerated password cracker. Desktop-only.
#
# The RTX 5080 (Blackwell, sm_120) is already exposed: clinfo reports
# "NVIDIA CUDA → NVIDIA GeForce RTX 5080" on the live system, and driver
# nvidia-x11-595.x (>>570 Blackwell floor) ships the userspace libs hashcat
# dlopens at runtime. The bare hashcat package does NOT add those libs to its
# own loader path, so we wrap it. Two distinct things must resolve:
#
#   1. libcuda.so        (CUDA driver runtime) → from the driver. Lets hashcat
#                         talk to the card. Loaded by the wrap's LD_LIBRARY_PATH.
#   2. libnvrtc.so       (NVRTC — Runtime Compilation) → from the CUDA *toolkit*,
#       + libnvjitlink.so   NOT the driver. hashcat's CUDA backend JIT-compiles
#                         its kernels via NVRTC at runtime; without it you get
#                         "Failed to initialize NVIDIA RTC library" and a silent
#                         fallback to the (slower) OpenCL backend. NVRTC needs
#                         libnvjitlink on sm_120. We pull just those two small
#                         libs from cudaPackages (12.9 — ≥12.8 = Blackwell-capable;
#                         compiled kernels run on the driver's CUDA 13.2 fine).
#
# Result: hashcat -I shows the 5080 under BOTH backends and uses CUDA by default.
#
# No capabilities/wrapper needed: hashcat is a compute tool that reads local
# hash files, not a network capture tool. It needs the GPU, not root.
#
# Recommended runtime flags for this card (per-run, NOT baked in — high
# workload profiles make the desktop laggy, so choose per job):
#   hashcat -m <mode> -a 0 hash.txt wordlist.txt
#     -d 1     restrict to CUDA device(s) (the 5080)
#     -O       optimized kernels (cap password len 55, faster)
#     -w 3     workload profile "night" (max GPU utilization)
#   hashcat -I              list backends/devices the wrapper exposes
#   hashcat -b -m 0         benchmark raw GPU throughput on MD5

let
  nvidiaDriver = config.hardware.nvidia.package;
  cuda = pkgs.cudaPackages;

  # Wrap hashcat so its runtime dlopens resolve:
  #   libcuda.so        (driver)        → CUDA backend talks to the 5080
  #   libOpenCL.so      (ocl-icd)       → OpenCL backend / fallback
  #   libnvrtc.so       (cuda_nvrtc)    → JIT-compile the CUDA kernels (RTC)
  #   libnvjitlink.so   (libnvjitlink)  → NVRTC link step on sm_120
  hashcat = pkgs.symlinkJoin {
    name = "hashcat";
    paths = [ pkgs.hashcat ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/hashcat \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [
          nvidiaDriver pkgs.ocl-icd cuda.cuda_nvrtc cuda.libnvjitlink
        ]} \
        --set-default CUDA_DEVICE_ORDER PCI_BUS_ID
    '';
  };
in
{
  environment.systemPackages = [ hashcat ];
}
