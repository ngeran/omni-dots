# PLAN — k8s-lab Phase 1: from-scratch Kubernetes + Cilium on KVM (Arch guests)

Status: **DRAFT r3 — Arch pivot, awaiting user approval. Not started.**
Date: 2026-11-21
Session scope: Phase 1 only. Later phases are direction, not commitments.

## Context

A disposable Kubernetes lab that never touches the `omni-nix` desktop config:
three minimal Arch Linux VMs on the desktop's existing libvirt/KVM
(socket-activated, `modules/apps/virtualization.nix`), workspace in
`~/k8s-lab`. Every Kubernetes component is placed and started by hand over
ssh, one at a time, each with a validation gate — the point is learning by
doing and validating, not operating.

## Decision log

- **r1/r2 (superseded):** NixOS guests + hand-rolled NixOS modules pushed via
  `nixos-rebuild --target-host`. Steps 1–4 were executed and committed on that
  basis (git history `d2f6208`…`31e08c7`).
- **r3 pivot (user, 2026-11-21):** *"I want to install the cluster myself so I
  can learn… I was thinking arch linux which we have more control — ssh to the
  VM and run the commands to deploy the cluster one at a time."* Full Arch
  rebuild; NixOS guests retired. Verified same day: arch-boxes ships official
  qcow2 images (`basic` + `cloudimg`, with SHA256); Arch `extra/kubernetes` is
  **1.37.2** (three minors past our target) → k8s+etcd come from **upstream
  tarballs pinned to 1.35.0 / 3.6.7**; `containerd` 2.4.2 exists in `extra`;
  `xorriso` (nixpkgs) builds NoCloud seed ISOs (`genisoimage` attr absent).
- **Mode (user, 2026-11-21):** "You drive, I guide." From the base-prep step
  on, the USER types every command over ssh; I brief (what/why/commands/expected
  output), we verify together, then tick + commit. I only do mechanical
  plumbing (VM provisioning, snapshots, docs, repo rework) — marked **[mech]**
  below; everything else is **[you]**.

## Locked decisions

| Decision | Choice |
|---|---|
| Guest distro | Arch Linux, official `arch-boxes` **cloudimg** qcow2 (base + cloud-init + sshd, nothing else); first-boot config via NoCloud seed ISO whose source files live in the repo |
| k8s + etcd binaries | upstream tarballs, pinned: `kubernetes-server-linux-amd64.tar.gz` **v1.35.0** (dl.k8s.io), `etcd-v3.6.7-linux-amd64.tar.gz` (github releases); placed in `/usr/local/bin` by hand; sha256-verified |
| Plumbing (containerd, runc, cni-plugins) | pacman, current versions (containerd 2.4.2 verified in `extra`); no `pacman -Syu` mid-lab |
| etcd | single member on cp-1, TLS everywhere; HA later |
| CNI | Cilium via Helm OCI chart, pinned `1.20.5`, `kubeProxyReplacement=false` initially |
| kube-proxy | DaemonSet, mode iptables, kubeconfig as kubectl-created Secret, never committed |
| Kubelet auth | static per-node certs/kubeconfigs; Webhook authn/authz on the kubelet API |
| Guests | 4 vCPU / 4 GiB / 30 GiB thin qcow2 (backing-file clones of the base), SeaBIOS (`--machine pc`), virtio everywhere, no autostart |
| Guest firewall | none installed (Arch base ships none) — lab-only, host NAT is the boundary |
| VM network | libvirt default NAT `192.168.122.0/24`; static IPs in the guest are the single source of truth (cp-1 `.10`, worker-1 `.21`, worker-2 `.22`); **MACs pinned**: cp-1 `52:54:00:aa:00:0a`, worker-1 `52:54:00:aa:00:15`, worker-2 `52:54:00:aa:00:16`; DNS via `192.168.122.1` |
| Cluster CIDRs | pods `10.42.0.0/16`, services `10.43.0.0/16`, cluster DNS `10.43.0.10` |
| Images | `/mnt/WD_BLACK-500GB/k8s-lab/` (dedicated NVMe): `images/` base + per-node clones, `seeds/` ISOs |
| SSH access | existing lab keypair `~/.ssh/k8s-lab_ed25519`; root key-only per node |
| Snapshots | disk-only, taken/restored **for all three nodes together** |
| Host tooling | `~/k8s-lab` devShell only (kubectl, etcdctl, helm, cilium-cli, hubble, openssl, jq, virsh/virt-install, xorriso); nothing installed into omni-nix |

## Conventions

- **Secrets/keys never committed.** `pki/`, `*.kubeconfig`, seed/user-data with
  keys, ISOs: gitignored. Keys on nodes live 0600 root-owned at
  `/var/lib/kubernetes` / `/etc/kubernetes/kubelet`. In-cluster secrets via
  `kubectl create secret` at apply time.
- Every flag verified against `<binary> --help` on the node before use; every
  cloud-init field against the NoCloud datasource docs; no invented APIs.
- One commit per step after its check passes; `git -C ~/k8s-lab …` always.
- Check command per step must pass before ticking the box.
- Re-provisioning a VM ⇒ new host keys ⇒ `ssh-keygen -R 192.168.122.<ip>` on
  the host first.
- `LIBVIRT_DEFAULT_URI=qemu:///system` everywhere (devShell exports it;
  scripts pass `--connect` explicitly).
- Guide steps land in the runbook (`k8s_deployment_step_by_step.md`) as they
  are executed — the doc is the course.

## Out of scope (future phases, do not build now)

kube-proxy replacement, HA etcd, kubelet TLS bootstrap + rotation, guest
firewall hardening, metal promotion via EX2300 VLAN, Mac-mini inference
endpoint, storage class, ingress/Gateway API, kube-prometheus-stack,
metrics-server, Gitea CI/CD, AWX, GPU scheduling.

## Steps

### 1. Retire the NixOS lab **[mech]**
- `virsh destroy` + `undefine` cp-1 / worker-1 / worker-2; delete their qcow2s
  from `/mnt/WD_BLACK-500GB/k8s-lab/` (snapshots die with the disks). Keep the
  directory, the ssh keypair, MAC/IP map, and `~/.ssh/config` blocks.
- Check: `virsh list --all` empty; only seeds/images dirs remain (empty).
- [x]

### 2. Fetch + verify the Arch cloudimg base **[mech]**
- Download `Arch-Linux-x86_64-cloudimg.qcow2` + `.SHA256` from
  `https://geo.mirror.pkgbuild.com/images/latest/`; `sha256sum -c`; store as
  `/mnt/WD_BLACK-500GB/k8s-lab/images/arch-cloudimg-base.qcow2` (read-only
  base, never booted); `setfacl -m u:qemu-libvirtd:r` on it.
- Check: sha256 verifies; `qemu-img info` shows qcow2 v3.
- [x]

### 3. Repo rework + cloud-init sources **[mech]**
- `flake.nix` shrinks to the devShell only (+ `xorriso`); `git rm` the NixOS
  configs (`modules/common.nix`, `modules/image.nix`, `modules/nodes/`) and the
  old provision script.
- `cloud-init/<node>/{user-data,meta-data}`: hostname; root ssh key only
  (`disable_root: false`, locked password, `ssh_pwauth: false`);
  `network: {config: disabled}`; `write_files`: `/etc/systemd/network/10-lan.network`
  (`[Match] Name=enp1s0 / ens3 / eth0` — one of them wins; `[Network]`
  Address/Gateway/DNS = static node IP + 192.168.122.1), `/etc/resolv.conf`,
  `/etc/hosts` (node's own entry; cp-1's includes `192.168.122.10 cp-1`);
  `runcmd`: enable --now `systemd-networkd` `systemd-timesyncd`.
- Check: `nix flake check`; `nix develop` works; files are valid YAML.
- [x]

### 4. Seed ISOs + provision script v2 **[mech]**
- `scripts/make-seed.sh <node>`: `xorriso -as mkisofs -volid cidata -joliet
  -rock` user-data+meta-data → `seeds/<node>-seed.iso`.
- `scripts/provision-vm.sh <node>`: thin clone
  (`qemu-img create -f qcow2 -F qcow2 -b <base>`), `setfacl` rw for
  qemu-libvirtd, refuse if domain/disk exists, then `virt-install --import`
  with: 4 vCPU / 4096 MiB / `--cpu host-passthrough` / `--machine pc`,
  virtio disk + `network=default,mac=<pinned>`, seed ISO as cdrom,
  guest-agent channel, `--nographics`, `--osinfo archlinux`, no autostart.
- Check: ISOs listed by `xorriso -indev … -ls`; `nix develop -c` parses the
  script (`bash -n`).
- [x]

### 5. Boot all three + verify base **[mech]**
- Provision cp-1, worker-1, worker-2; `ssh-keygen -R` old keys; wait for
  first boot (cloud-init runs once).
- Check: `virsh list --all` = 3 running; `ssh root@192.168.122.{10,21,22}`
  with the lab key; `ip -4 addr show` = the static IP; `ping -c1 1.1.1.1`;
  `getent hosts archlinux.org`; `systemctl is-active systemd-networkd
  systemd-timesyncd sshd`; `free -h` shows no swap.
- [x]

### 6. Base OS prep, per node **[you — guide mode starts here**
- Over ssh on each node: write `/etc/sysctl.d/k8s.conf` (ip_forward,
  bridge-nf-call-iptables/ip6tables, inotify limits) + `sysctl --system`;
  `/etc/modules-load.d/k8s.conf` (overlay, br_netfilter); `pacman -Sy` package
  databases once + `pacman -S containerd runc cni-plugins conntrack-tools
  socat ethtool ipset jq` (no -Syu mid-lab); confirm swap absent.
- Check per node: `sysctl net.ipv4.ip_forward` = 1; `lsmod | grep -E
  'overlay|br_netfilter'`; binaries in PATH; `systemctl status containerd` =
  inactive (started later, by hand, in its step).
- [ ]

### 7. Restore-point snapshot **[mech]**
- Shut all three down; `snapshot-create-as <node> bootstrap-clean` ×3; start
  them again.
- Check: `virsh snapshot-list` ×3 shows `bootstrap-clean`.
- [ ]

### 8. Runbook rework for Arch **[mech]**
- Rewrite Part 1 (VM ops) + Part 2 (deploy loop = ssh + scp + systemctl, no
  nixos-rebuild) of `k8s_deployment_step_by_step.md`; concepts (Part 0) and
  PKI (Part 4/Appendix A) stay.
- Check: doc renders; no NixOS deploy commands remain in Parts 1–2.
- [x] (done early, before step 6, on request — full rework: Part 4 = step 6
  runbook, PKI → Part 5, cards renumbered to 18-step plan)

### 9. PKI — CA + all certs + kubeconfigs **[you]**
- `scripts/pki.sh` on the host (idempotent, refuses to overwrite): cluster
  CA + front-proxy CA; etcd server+peer (SANs 127.0.0.1, 192.168.122.10, cp-1;
  both EKUs) + apiserver→etcd client; apiserver serving (SANs 192.168.122.10,
  127.0.0.1, 10.43.0.1, cp-1, k8s.lab, kubernetes[.default[.svc[.cluster.local]]]);
  apiserver→kubelet client (O=system:masters); sa.key/sa.pub; admin
  (O=system:masters), system:kube-controller-manager, system:kube-scheduler,
  system:kube-proxy; kubelet client certs CN=system:node:<n>, O=system:nodes +
  kubelet serving certs (IP+name SANs). Kubeconfigs (embedded certs) for all
  components at `https://192.168.122.10:6443`.
- scp to `/var/lib/kubernetes` (cp-1) and `/etc/kubernetes/kubelet` (each
  node), 0600 root.
- Check: `openssl verify` against ca.crt for every cert; SANs/CN/EKU via
  `openssl x509 -text`; `git status` shows no keys tracked.
- [ ]

### 10. etcd on cp-1 **[you]**
- Download + sha256-verify `etcd-v3.6.7` tarball; `/usr/local/bin/{etcd,etcdctl}`;
  hand-write `/etc/systemd/system/etcd.service`: client+peer TLS
  (`clientCertAuth`, `peerClientCertAuth`), listen 127.0.0.1+node IP, peer URL
  on node IP, single-member initial cluster, data dir `/var/lib/etcd`;
  `systemctl enable --now etcd`.
- Check: `etcdctl --endpoints=https://192.168.122.10:2379 endpoint health`,
  `member list`, put/get roundtrip, `snapshot save` (first backup drill).
- [ ]

### 11. kube-apiserver on cp-1 **[you]**
- k8s **v1.35.0** server tarball → `/usr/local/bin/`; hand-write unit
  (`After=etcd.service`, Restart=always). Flags (each checked with
  `kube-apiserver --help`): etcd servers+certs, `--service-cluster-ip-range=
  10.43.0.0/16`, SA key/signing-key/issuer flags, `--authorization-mode=Node,
  RBAC`, `--enable-admission-plugins=NodeRestriction`, `--client-ca-file`,
  serving TLS, kubelet client cert, `--kubelet-preferred-address-types=
  InternalIP`, `--anonymous-auth=false`, requestheader/proxy-client flags.
- Check: `kubectl --kubeconfig pki/admin.kubeconfig get --raw /healthz`,
  `/readyz`, `/livez` → ok; anonymous curl to :6443 → **401**.
- [ ]

### 12. controller-manager + scheduler on cp-1 **[you]**
- Hand-written units + kubeconfigs; leader election left **on** (single
  replica is fine and creates the Leases the check uses).
- controller-manager: `--root-ca-file`, `--service-account-private-key-file`,
  `--use-service-account-credentials`, `--cluster-signing-cert-file/-key-file`,
  `--allocate-node-cidrs=false` (Cilium owns IPAM),
  `--authentication-kubeconfig/--authorization-kubeconfig`.
- Check: `kubectl -n kube-system get lease` shows both; `kubectl get
  namespaces` → default, kube-system; default SA exists.
- [ ]

### 13. containerd + kubelet on all three **[you]**
- containerd: hand-write `/etc/containerd/config.toml` (SystemdCgroup=true,
  CRI CNI bin_dir `/opt/cni/bin`, conf_dir `/etc/cni/net.d`); create
  `/opt/cni/bin` as a real dir and copy the loopback plugin from the pacman
  cni-plugins dir (`pacman -Ql cni-plugins` → copy loopback) — Cilium writes
  its own binary there later; `systemctl enable --now containerd`.
- kubelet: v1.35.0 binaries; hand-written unit + KubeletConfiguration:
  cgroupDriver systemd, containerRuntimeEndpoint, clusterDNS
  [10.43.0.10], clusterDomain cluster.local, failSwapOn true, serving certs,
  webhook authn (anonymous off) + authz, resolvConf = real upstream (not a
  127.0.0.x stub), `--node-ip`, `--hostname-override`; cp-1 registers with
  taint `node-role.kubernetes.io/control-plane:NoSchedule`.
- Check: `kubectl get nodes` = 3 × **NotReady** ("cni plugin not initialized"
  — the gate); `crictl info` shows runtime ready except network.
- Optional: snapshot `pre-cni` on all three **together**.
- [ ]

### 14. kube-proxy DaemonSet **[you]**
- `manifests/kube-proxy.yaml`: KubeProxyConfiguration mode iptables,
  clusterCIDR 10.42/16, apiserver `https://192.168.122.10:6443`; mounts
  `/run/xtables.lock`, `/lib/modules` (ro); kubeconfig via
  `kubectl create secret`, never committed.
- Check: ds 3/3 ready; `iptables-save | grep KUBE-SERVICES`; from a node
  `curl -k https://10.43.0.1/healthz` answers (401/403 proves ClusterIP).
- [ ]

### 15. Cilium **[you]**
- Helm OCI `--version 1.20.5` into kube-system; committed
  `manifests/cilium-values.yaml`: `kubeProxyReplacement: false`, cluster-pool
  IPAM 10.42/16, `k8sServiceHost: 192.168.122.10`, port 6443,
  `cni.binPath: /opt/cni/bin`, operator.replicas 1, Hubble relay on.
  (Matrix re-check before install: 1.20.5 ↔ k8s 1.33–1.36 ✓ 2026-11-21.)
- Check: `cilium status --wait`; nodes **Ready**;
  `kubectl -n kube-system exec ds/cilium -- cilium-dbg status` healthy.
- [ ]

### 16. CoreDNS **[you]**
- Pinned manifest, ClusterIP `10.43.0.10`, forward to node resolv.conf.
- Check: busybox:1.28 pod: `nslookup kubernetes.default` + external
  `nslookup example.com` (1.28 — newer busybox nslookup lies).
- [ ]

### 17. Smoke + NetworkPolicy demo **[you]**
- Deployment (2 replicas across workers) + NodePort reachable from host over
  NAT; `cilium connectivity test` (memory peak; exercises kubelet exec/logs);
  default-deny policy blocks curl → allow policy unblocks (allow DNS egress
  if egress denied).
- Check: all three pass; results in `README.md`.
- [ ]

### 18. Wrap-up **[mech]**
- Stop VMs; snapshot `phase1-complete` ×3 together; `README.md` with
  architecture, node/CIDR table, restore procedure; final commit.
- Check: `virsh snapshot-list` ×3; `git log --oneline` one commit per step;
  `git status` clean.
- [ ]

## Risks / notes

- **cloudimg NIC name** unknown until first boot — mitigated by matching
  `enp1s0|ens3|eth0` in the networkd unit; verify with `networkctl` at step 5.
- **cloud-init quirks:** seed files are plain text in the repo; serial console
  (`virsh console`, the image ships a serial-capable bootloader — verify) is
  the rescue path; `bootstrap-clean` snapshot taken only after step 5 passes.
- **Arch rolling:** only plumbing comes from pacman; k8s/etcd tarballs pinned.
  No `-Syu` mid-lab (single `-Sy` for the DB at step 6).
- **containerd 2.4.2 (pacman)** vs the 2.2.1 originally locked: plumbing only,
  CRI is stable — acceptable drift, noted here deliberately.
- `kubectl get componentstatuses` gone in 1.35 → health via `/healthz` +
  Leases (step 12).
- Static kubelet certs don't rotate — long validity, rotation later.
- devShell verified at pinned nixpkgs rev 2026-11-21: virt-manager 5.1.0
  provides virt-install; `xorriso` = `libisoburn` attr.
