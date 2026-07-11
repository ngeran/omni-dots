# =============================================================================
# k3s — single-node Kubernetes for the k8s-telemetry lab
# =============================================================================
#
# WHAT THIS IS
#   A self-contained k3s server (lightweight Kubernetes) for the k8s-telemetry
#   lab. Runs as a single-node control plane + worker:
#     - role = "server", clusterInit left at its default false -> standalone
#       server with the embedded SQLite datastore (NOT etcd, NOT HA).
#     - k3s bundles its own containerd, so it does NOT depend on and does NOT
#       conflict with the system Docker from modules/apps/virtualization.nix.
#       The two runtimes (k3s containerd, system dockerd) coexist fine.
#
# SCOPE / STATUS
#   This module is WRITTEN but NOT imported anywhere. Nothing on the system
#   changes until you wire it in. This respects the lab rule: nothing installs
#   until explicitly enabled.
#
# HOW TO ENABLE  (desktop / nixos-btw ONLY — do NOT import on dell3440)
#   1. Edit hosts/desktop/default.nix; add this line to the `imports` list:
#          ../../labs/k8s-telemetry/nix/k3s.nix
#   2. Stage it so the flake can see it (flakes evaluate the git index, NOT
#      the working tree — unstaged files are invisible to omni-apply):
#          git -C ~/.omni-nix add labs/k8s-telemetry/nix/k3s.nix hosts/desktop/default.nix
#   3. Bootstrap the persistent data dir ONCE, before the first start (the
#      bind-mount target must exist at mount time; k3s will not create it for
#      you because it writes *under* the already-mounted path):
#          sudo mkdir -p /persist/var/lib/rancher/k3s
#   4. Apply:
#          omni-apply
#      (If you skipped step 3 and k3s failed to start at boot, run step 3 now
#      then: sudo systemctl restart k3s)
#
# PERSISTENCE
#   k3s has no `dataDir` option — its state is hardcoded to /var/lib/rancher/k3s.
#   To keep that state under /persist (the repo convention: Docker's data-root
#   and the nvim bind mounts both live there), this module bind-mounts
#   /var/lib/rancher/k3s <- /persist/var/lib/rancher/k3s. See the fileSystems
#   block below for why this uses a plain `bind` and NOT the
#   `noauto x-systemd.automount` pattern used for nvim.
#
# KUBECONFIG ACCESS  (user nikos)
#   - Quickest: the k3s package is on PATH (the module adds it to
#     environment.systemPackages), so `k3s kubectl get nodes` works with no
#     further setup.
#   - Standalone kubectl: the kubeconfig is written to
#     /etc/rancher/k3s/k3s.yaml. extraFlags below set --write-kubeconfig-mode
#     644 so nikos can read it without sudo:
#         export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
#         kubectl get nodes
#     Or copy it once:  mkdir -p ~/.kube && \
#         cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
#     (refresh the copy only if you rebuild the cluster from scratch).
#   - kubectl / k9s / helm / gnmic are NOT installed by this module. See the
#     commented snippet at the bottom for adding them to dev-tools.nix.
#
# GOTCHAS
#   - Flakes read the git index: `git add` this file or omni-apply ignores it.
#   - k3s + Docker coexist (separate runtimes); the old `services.k3s.docker`
#     option was removed upstream and is now a hard error if set.
#   - NixOS firewall is on by default and k3s does NOT open ports for you.
#     Local access (kubectl, port-forwards to 127.0.0.1) works; reaching a
#     NodePort from another machine needs networking.firewall openings.
#   - /persist is currently a plain directory on the root ext4 filesystem, NOT
#     a separate volume — it survives reboots only because / does. The bind
#     mount is forward-compatible: if /persist later becomes its own disk,
#     k3s state follows automatically.
#   - --write-kubeconfig-mode 644 makes /etc/rancher/k3s/k3s.yaml world-
#     readable (cluster-admin creds). Fine for an isolated single-user desktop
#     lab; do NOT reuse this on a shared/multi-user host.
#   - k3s runs continuously on a daily-driver desktop (~300-600 MB RAM idle
#     plus your workloads). Disable by removing the import and rebuilding.
# =============================================================================

{ config, pkgs, ... }:

{
  # =========================================================================
  # 1. k3s Service — single-node server, embedded SQLite datastore
  # =========================================================================
  services.k3s = {
    enable = true;
    role = "server";            # server also runs workloads (agent+server)

    # clusterInit defaults to false -> standalone server with embedded SQLite,
    # NOT an HA etcd cluster. Exactly what a single-node lab wants.
    # (So: no clusterInit = true, and no tokenFile — a 1-node setup needs none.)

    extraFlags = [
      # Make /etc/rancher/k3s/k3s.yaml readable by non-root user `nikos`
      # (default mode is 0600). Lets kubectl work without sudo.
      "--write-kubeconfig-mode 644"

      # Cluster CIDRs — these are the k3s defaults, made explicit for lab
      # clarity. Pods: 10.42.0.0/16, Services: 10.43.0.0/16.
      "--cluster-cidr 10.42.0.0/16"
      "--service-cidr 10.43.0.0/16"
    ];

    # No ingress controller: this lab is reached via `kubectl port-forward`,
    # not HTTP ingress. Disabling traefik avoids a component we don't use.
    # (Add "servicelb" here too if you don't want the bundled ServiceLB
    # spawning pods — usually desirable on a single-node lab.)
    disable = [ "traefik" ];

    # Future lab workloads: auto-deploying manifests can be added via
    #   manifests.foo = { content = { ... }; };
    # They are symlinked into /var/lib/rancher/k3s/server/manifests by
    # systemd-tmpfiles before k3s starts. Left empty for now — the lab uses
    # plain YAML under ../manifests/ applied with `kubectl apply`.
  };

  # =========================================================================
  # 2. Persistent State — bind /var/lib/rancher/k3s onto /persist
  # =========================================================================
  # k3s's data dir is hardcoded (/var/lib/rancher/k3s, no dataDir option).
  # Bind it onto /persist/var/lib/rancher/k3s so state lives on the same
  # persistent location as Docker's data-root and the nvim bind mounts —
  # keeping the repo's "/persist holds all state" convention.
  #
  # Mount strategy: plain `bind` (mounted at boot via local-fs.target), NOT
  # the `noauto x-systemd.automount` used for nvim. Justification:
  #   - k3s is a boot-time systemd service that needs its data dir present
  #     and writable the instant it starts.
  #   - The k3s NixOS module uses systemd-tmpfiles to create manifest/image
  #     symlinks under /var/lib/rancher/k3s/server/... BEFORE k3s starts; those
  #     symlinks must land on the mounted (persistent) fs, not on the shadowed
  #     underlying directory. With `noauto`, tmpfiles-setup could run before
  #     the automount fires -> symlinks land on the root fs and get hidden when
  #     the bind later mounts over them.
  #   - The module sets no RequiresMountsFor= on /var/lib/rancher/k3s, so
  #     `noauto` gives no ordering guarantee relative to k3s.service.
  #   - Plain `bind` is mounted during early boot (local-fs.target), before
  #     systemd-tmpfiles-setup.service and before k3s.service -> dir is ready,
  #     symlinks persist correctly.
  #   - Safe here because /persist sits on the root ext4 fs (mounted in the
  #     initrd via x-initrd.mount), so it is available well before local-fs
  #     bind mounts run.
  # The repo's `noauto x-systemd.automount` pattern is right for on-demand
  # user tools (nvim) but wrong for a boot-critical daemon.
  #
  # BOOTSTRAP (once, before first start):  sudo mkdir -p /persist/var/lib/rancher/k3s
  # The mount target MUST exist at mount time or the bind fails at boot.
  fileSystems."/var/lib/rancher/k3s" = {
    device = "/persist/var/lib/rancher/k3s";
    fsType = "none";
    options = [ "bind" ];
  };

  # =========================================================================
  # 3. Lab CLI tools — installed WITH the lab (when this module is imported)
  # =========================================================================
  # These come on when you enable k3s and off when you remove the import, so
  # the whole lab (service + tooling) is behind one switch — honoring the
  # "nothing installs until enabled" rule. `k3s kubectl` already works once
  # k3s is up (the k3s module adds the k3s binary to PATH), but the standalone
  # `kubectl` is nicer to type; k9s is the cluster TUI; gnmic is for host-side
  # gNMI capability/subscribe testing (the in-cluster gnmic does the actual
  # collection). helm is OMITTED — this lab uses plain YAML, no Helm charts;
  # add `kubernetes-helm` here if you want it (3.20.2 in nixpkgs).
  environment.systemPackages = with pkgs; [
    kubectl            # standalone client (nixpkgs 1.36.2)
    k9s                # TUI cluster explorer (nixpkgs 0.50.18)
    gnmic              # gNMI telemetry client (nixpkgs 0.46.0)
  ];
}
