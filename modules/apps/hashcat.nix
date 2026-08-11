{ config, lib, pkgs, ... }:

# hashcat 7.1.2 — GPU-accelerated password cracker. Desktop-only.
#
# The RTX 5080 (Blackwell, sm_120) is already fully exposed: clinfo reports
# "NVIDIA CUDA → NVIDIA GeForce RTX 5080" on the live system, and driver
# nvidia-x11-595.x (>>570 Blackwell floor) ships the userspace libs hashcat
# dlopens at runtime. What the *bare* hashcat package does NOT do is add those
# driver libs to its own loader path — so hashcat -I would find no GPU backend.
# We wrap it to expose them, which is what makes the CUDA backend (hashcat's
# fastest on NVIDIA, and the one that drives Blackwell) actually load.
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

  # Wrap hashcat so its dlopen of libcuda.so (CUDA backend) and libOpenCL.so
  # (ocl-icd loader → libnvidia-opencl.so) resolves against the running driver.
  hashcat = pkgs.symlinkJoin {
    name = "hashcat";
    paths = [ pkgs.hashcat ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/hashcat \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ nvidiaDriver pkgs.ocl-icd ]} \
        --set-default CUDA_DEVICE_ORDER PCI_BUS_ID
    '';
  };
in
{
  environment.systemPackages = [ hashcat ];
}
