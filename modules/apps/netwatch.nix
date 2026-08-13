{ pkgs, inputs, ... }:

# netwatch (matthart1983) — real-time network diagnostics TUI: "htop for your
# network". Rust + libpcap; per-process connections, TLS/QUIC/HTTP/DNS decode,
# JA4 fingerprinting, C2-beaconing/port-scan detection, egress learning.
# Desktop-only.
#
# Built from the UPSTREAM flake (github:matthart1983/netwatch, pinned in
# flake.nix) which ships its own buildRustPackage using the committed Cargo.lock
# — we consume its `default` package rather than re-deriving cargo hashes, so
# upstream dep changes are picked up on a flake update, not on every rebuild.
#
# Like sniffnet, live capture needs privileges. Per the upstream README the
# minimal capability set for running the FULL tool (live packet capture + eBPF
# health probes + perf-event monitoring) without sudo is:
#     cap_net_raw  — raw sockets / libpcap capture
#     cap_bpf      — load eBPF programs (kernel >= 5.8; we run linuxPackages_latest)
#     cap_perfmon  — perf-event monitoring
# granted once on the binary via a setcap wrapper. Non-capture features
# (interface stats, the connection list, config) work with NO caps at all; the
# wrapper only unlocks live capture + the deep-inspection tabs.
#
# Why a system module: security.wrappers is NIXOS-only (not home-manager).

let
  netwatchPkg = inputs.netwatch.packages.${pkgs.system}.default;
in
{
  # Pull the package in (binary, completions) and cap-wrap the executable so the
  # full feature set runs unprivileged. /run/wrappers/bin is ahead of the system
  # profile on PATH, so a bare `netwatch` resolves to the capped wrapper.
  environment.systemPackages = [ netwatchPkg ];

  security.wrappers.netwatch = {
    source = "${netwatchPkg}/bin/netwatch";
    capabilities = "cap_net_raw,cap_bpf,cap_perfmon+eip";
    owner = "root";
    group = "users";
    permissions = "u+rx,g+rx"; # users group can execute; 'other' cannot
  };
}
