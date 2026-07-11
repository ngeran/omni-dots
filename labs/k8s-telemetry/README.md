# 🛰️ K8s Network Telemetry Lab (gNMI → Prometheus / Loki / Grafana on k3s)

A self-contained, **learning-only** lab that stands up a full network-telemetry
pipeline on a single-node k3s cluster running on the `nixos-btw` desktop: a gNMI
target simulator → **gnmic** collector → **Prometheus** (metrics) + **Loki**
(logs) → **Grafana** (dashboards). It is wired through a NixOS module
(`services.k3s`) that is **written but not imported by default** — nothing is
installed until you explicitly opt in by adding one import line. This is not
production tooling; it's a scratchpad for learning OpenConfig gNMI, the gnmic
collector, and the Grafana stack on your own machine.

> Juniper **cRPD** is *not* used as the primary target: it is not on Docker Hub
> and requires a license. The lab uses a **free Docker-Hub gNMI simulator**
> (`flex/frr-gnmi-target`) instead. cRPD is an optional bring-your-own phase
> (Phase 6).

---

## 🧭 Architecture

```
┌─────────────────────── namespace: telemetry ───────────────────────┐
│                                                                    │
│   ┌────────────────────┐         gNMI  (gRPC :9339)                │
│   │  gNMI target       │  ◄──────────────────────────────┐         │
│   │  (free simulator)  │   Subscribe / Get / Capabilities │         │
│   │  flex/frr-gnmi-    │  ──────────────────────────────► │         │
│   │  target            │                                  ▼         │
│   └────────────────────┘                          ┌──────────────┐  │
│                                                  │   gnmic      │  │
│                                                  │  (collector) │  │
│                                                  └───┬──────┬───┘  │
└──────────────────────────────────────────────────────┼──────┼──────┘
                    /metrics :9804 (scrape)            │      │  events (push)
                                                       │      │
┌──────────────────── namespace: monitoring ───────────▼──────▼──────┐
│   ┌──────────────────┐                ┌──────────────────┐         │
│   │   Prometheus     │                │      Loki        │         │
│   │  (scrapes gnmic) │                │   (event logs)   │         │
│   └────────┬─────────┘                └────────┬─────────┘         │
│            └──────────────┬────────────────────┘                   │
│                           ▼                                         │
│                  ┌──────────────────┐                               │
│                  │     Grafana      │  dashboards query             │
│                  │                  │  Prometheus + Loki            │
│                  └──────────────────┘                               │
└─────────────────────────────────────────────────────────────────────┘
```

- **gnmic** subscribes to the gNMI target, exposes collected counters as
  Prometheus metrics on `:9804`, and can push structured event logs to Loki.
- **Prometheus** scrapes gnmic; **Grafana** reads from both Prometheus and Loki.
- Images pull from **Docker Hub** directly, with one exception: `gnmic` is on
  **GHCR** (`ghcr.io/openconfig/gnmic`) — it is not reliably published to Docker
  Hub. Still a public registry pull, just not Docker Hub.

---

## ✅ Assumptions — verified vs flagged

| Item | Status | Note |
|---|---|---|
| Host = `nixos-btw` desktop (NixOS 26.05 flake) | ✅ Verified | Desktop-only; do not enable on `dell3440`. |
| k3s single-node via NixOS `services.k3s` | ✅ Verified | Embedded containerd; does not touch the existing Docker daemon. |
| `local-path` storage (k3s default) | ✅ Verified | Ships with k3s; used for PVs if needed. |
| Namespaces: `telemetry`, `monitoring`, `network`, `lab` | ✅ Verified | Declared in `manifests/00-namespaces.yaml`. |
| Images from Docker Hub (pinned tags) | ✅ Verified | `prom/prometheus:v3.12.0`, `grafana/grafana:11.6.16`, `grafana/loki:3.5.1`, `flex/frr-gnmi-target:1sec`. |
| gnmic image on GHCR | 🚩 Deviation | `ghcr.io/openconfig/gnmic:0.46.0` — not on Docker Hub. Public registry pull. |
| k3s state persisted to `/persist` (bind mount) | ✅ Verified | Mirrors the existing `/persist/var/lib/docker` pattern in `modules/apps/virtualization.nix`. |
| k3s module written but **not imported by default** | ✅ Verified | Opt-in via one import line (see *Enabling k3s*). |
| **Internal-registry / mirror policy (`<INTERNAL_REGISTRY>`)** | 🚩 N/A | Original spec called for a company registry mirror. This is a home lab → we pull from Docker Hub / GHCR directly. |
| **Air-gap / no-public-clone / no-public-Helm policy** | 🚩 N/A | Original spec forbade cloning public repos / public Helm charts. N/A here: we still author **plain YAML manifests by hand (no Helm)** for learning, but the air-gap rationale does not apply. |
| **cRPD (Juniper) image + license** | 🚩 Open | Not on Docker Hub + needs a license. Replaced by a **free gNMI simulator** as the primary target. cRPD is optional, bring-your-own (Phase 6). |
| **gNMI target listen port** | 🚩 Verify | `flex/frr-gnmi-target:1sec` declares no EXPOSE; assumed **9339** (IANA gNMI port). Verify on first apply (Phase 2). |

---

## 📂 What this directory contains

```text
labs/k8s-telemetry/
├── README.md                # this file
├── nix/
│   └── k3s.nix              # NixOS module: services.k3s + /persist bind mount (NOT imported by default)
└── manifests/
    ├── 00-namespaces.yaml   # ns: telemetry, monitoring, network, lab
    ├── 10-gnmi-target.yaml  # flex/frr-gnmi-target:1sec — Deployment + Service (gNMI :9339)
    ├── 20-gnmic.yaml        # gnmic collector — ConfigMap + Deployment + Service (:9804)
    ├── 30-prometheus.yaml   # prom/prometheus:v3.12.0 — ConfigMap + Deployment + Service (:9090)
    ├── 40-loki.yaml         # grafana/loki:3.5.1 — ConfigMap + StatefulSet + Service (:3100)
    ├── 50-grafana.yaml      # grafana/grafana:11.6.16 — Deployment + Service + Provisioned datasources
    └── 60-crpd.yaml         # OPTIONAL (Phase 6): cRPD — bring-your-own image + license Secret
```

- `nix/k3s.nix` is the **only** file that touches the host system. Everything
  under `manifests/` is plain Kubernetes YAML applied with `kubectl` — no Helm,
  no cloned public charts.
- `manifests/60-crpd.yaml` is intentionally stubbed; it only becomes live if you
  supply a cRPD image and license (Phase 6).

---

## 📐 Phased build plan

Apply manifests in order; each phase builds on the previous. **Phases 2–5
require k3s to be enabled first (see *Enabling k3s*).**

### Phase 1 — k3s up + namespaces
- **Goal:** a running single-node k3s cluster with the lab namespaces.
- **Files:** `nix/k3s.nix`, `manifests/00-namespaces.yaml`, edit `hosts/desktop/default.nix`.
- **Enable / apply:**
  ```bash
  sudo mkdir -p /persist/var/lib/rancher/k3s          # bootstrap persisted state dir (once)
  # add  ../../labs/k8s-telemetry/nix/k3s.nix  to the imports list in hosts/desktop/default.nix
  git -C ~/.omni-nix add labs/k8s-telemetry/nix/k3s.nix hosts/desktop/default.nix
  omni-apply
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml        # or copy to ~/.kube/config (see Enabling k3s)
  kubectl apply -f manifests/00-namespaces.yaml
  ```
- **Verify:** `kubectl get nodes` → `Ready`; `kubectl get ns` → `telemetry`, `monitoring` listed.
- **Expected:** one Ready node, all four namespaces present.

### Phase 2 — gnmic + gNMI target
- **Goal:** a free gNMI simulator serving synthetic counters, and gnmic subscribed to it.
- **Files:** `manifests/10-gnmi-target.yaml`, `manifests/20-gnmic.yaml`.
- **Apply:** `kubectl apply -f manifests/10-gnmi-target.yaml -f manifests/20-gnmic.yaml`
- **Verify the gNMI port first** (the `flex/frr-gnmi-target` image declares no EXPOSE):
  ```bash
  kubectl -n telemetry exec deploy/gnmi-target -- sh -c 'ss -ltnp 2>/dev/null || netstat -ltnp'
  # if it listens on something other than 9339, edit 10-gnmi-target.yaml (targetPort)
  # and the gnmic target address in 20-gnmic.yaml, then re-apply.
  ```
  Then: `kubectl -n telemetry get pods` → target + gnmic `Running`; and
  `kubectl -n telemetry exec deploy/gnmic -- gnmic -a gnmi-target:9339 -u admin -p admin capabilities`
- **Expected:** capabilities response with gNMI version and supported models/paths.

### Phase 3 — Prometheus
- **Goal:** scrape gnmic's `/metrics` on `:9804` and store time series.
- **Files:** `manifests/30-prometheus.yaml`.
- **Apply:** `kubectl apply -f manifests/30-prometheus.yaml`
- **Verify:** `kubectl -n monitoring port-forward svc/prometheus 9090`, then open
  `http://localhost:9090/targets` (or `curl -s localhost:9090/api/v1/targets | jq '.data.activeTargets[].health'`).
- **Expected:** the gnmic scrape target shows `UP`.

### Phase 4 — Loki
- **Goal:** receive structured event logs pushed by gnmic.
- **Files:** `manifests/40-loki.yaml`.
- **Apply:** `kubectl apply -f manifests/40-loki.yaml`
- **Verify:** `kubectl -n monitoring port-forward svc/loki 3100`, then `curl -s localhost:3100/ready`.
- **Expected:** body returns `ready`.

### Phase 5 — Grafana
- **Goal:** dashboards reading from both Prometheus and Loki, datasources auto-provisioned.
- **Files:** `manifests/50-grafana.yaml`.
- **Apply:** `kubectl apply -f manifests/50-grafana.yaml`
- **Verify:** `kubectl -n monitoring port-forward svc/grafana 3000:3000`, log in (`admin` / `admin`),
  check **Connections → Data sources**.
- **Expected:** Prometheus and Loki datasources both show as connected; build a panel querying gnmic metrics.

### Phase 6 — cRPD (OPTIONAL, bring-your-own)
- **Goal:** swap the simulator for a real Juniper cRPD gNMI target.
- **Files:** `manifests/60-crpd.yaml`.
- **Prereqs:** a cRPD image you can push to a registry the desktop can reach, and a valid cRPD
  license (loaded as a Kubernetes `Secret`, out-of-tree — never commit it).
- **Apply:** `kubectl apply -f manifests/60-crpd.yaml` (after editing in your image + license secret).
- **Verify:** `kubectl -n telemetry exec deploy/gnmic -- gnmic -a crpd:57400 -u <user> -p <pass> capabilities`.
- **Expected:** cRPD returns its gNMI capabilities. Skip this phase entirely if you have no cRPD
  license — Phases 1–5 are complete on their own.

---

## 🔌 Enabling k3s (the one-time system step)

k3s is **not** installed by default. The module exists at
`labs/k8s-telemetry/nix/k3s.nix` but is inert until imported. To turn it on
(desktop only — never add this to `hosts/dell3440`):

```bash
# 1. Bootstrap the persisted state dir (bind-mount target must exist before k3s starts)
sudo mkdir -p /persist/var/lib/rancher/k3s

# 2. Wire the module into the desktop host's import list
nvim ~/.omni-nix/hosts/desktop/default.nix
#   add this line to the `imports = [ ... ]` block:
#     ../../labs/k8s-telemetry/nix/k3s.nix

# 3. Stage (flakes read the git index — unstaged new files are invisible)
git -C ~/.omni-nix add labs/k8s-telemetry/nix/k3s.nix hosts/desktop/default.nix

# 4. (optional) dry-run to confirm evaluation is clean
sudo nixos-rebuild dry-activate --flake ~/.omni-nix#nixos-btw

# 5. Apply
omni-apply

# 6. Make kubeconfig usable as your user (default file is root-readable only,
#    but --write-kubeconfig-mode 644 makes it world-readable so this works)
mkdir -p ~/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config

# 7. Verify the cluster
k3s kubectl get nodes      # or: kubectl get nodes
```

**What `nix/k3s.nix` does:** enables `services.k3s` as a single-node `server`,
disables the bundled traefik (not needed; we use port-forwards), and bind-mounts
`/var/lib/rancher/k3s` → `/persist/var/lib/rancher/k3s` so cluster state survives
reboots (same `/persist` convention already used for Docker's `data-root` in
`modules/apps/virtualization.nix`).

> This installs a **real Kubernetes distribution** (k3s) and its embedded
> containerd on your daily-driver desktop. It coexists with Docker (separate
> runtimes) but consumes RAM/CPU. See *Risks & gotchas*.

---

## 🔍 Verification per phase (quick reference)

| Phase | Command | Expected |
|---|---|---|
| 1 — cluster | `kubectl get nodes` | one node, `Ready` |
| 1 — namespaces | `kubectl get ns` | `telemetry`, `monitoring`, `network`, `lab` present |
| 2 — pods | `kubectl -n telemetry get pods` | gnmi-target + gnmic `Running` |
| 2 — gNMI | `kubectl -n telemetry exec deploy/gnmic -- gnmic -a gnmi-target:9339 -u admin -p admin capabilities` | gNMI version + models list |
| 3 — prometheus | `kubectl -n monitoring port-forward svc/prometheus 9090` → `http://localhost:9090/targets` | gnmic target `UP` |
| 4 — loki | `kubectl -n monitoring port-forward svc/loki 3100` → `curl -s localhost:3100/ready` | `ready` |
| 5 — grafana | `kubectl -n monitoring port-forward svc/grafana 3000:3000` → log in `admin`/`admin` | Prometheus + Loki datasources connected |
| 6 — crpd | `kubectl -n telemetry exec deploy/gnmic -- gnmic -a crpd:57400 -u <u> -p <p> capabilities` | cRPD capabilities returned |

Port-forwards are local only and need no firewall changes.

---

## 🧹 Teardown / disable

**Tear down the manifests (keep k3s installed):**
```bash
kubectl delete -f manifests/60-crpd.yaml
kubectl delete -f manifests/50-grafana.yaml
kubectl delete -f manifests/40-loki.yaml
kubectl delete -f manifests/30-prometheus.yaml
kubectl delete -f manifests/20-gnmic.yaml
kubectl delete -f manifests/10-gnmi-target.yaml
kubectl delete -f manifests/00-namespaces.yaml
# order is not required, but deleting high-numbered first is tidy
```

**Fully disable k3s on the host:**
```bash
# 1. Remove the import line from hosts/desktop/default.nix
nvim ~/.omni-nix/hosts/desktop/default.nix     # delete: ../../labs/k8s-telemetry/nix/k3s.nix
git -C ~/.omni-nix add hosts/desktop/default.nix
omni-apply                                       # rebuild without k3s

# 2. (optional) wipe k3s entirely, including its state
sudo /usr/local/bin/k3s-uninstall.sh

# 3. (optional) clean the persisted state dir
sudo rm -rf /persist/var/lib/rancher/k3s

# 4. Remove your kubeconfig copy
rm -f ~/.kube/config
```
The lab files (`labs/k8s-telemetry/`) can stay in the repo — with the import
removed they are inert.

---

## ⚠️ Risks & gotchas

- **k3s + Docker coexist, but are separate runtimes.** k3s ships its own
  embedded containerd and does not use (or interfere with) the Docker daemon
  from `modules/apps/virtualization.nix`. Both run side by side; expect higher
  idle RAM/CPU. The old `services.k3s.docker` option is now a hard error.
- **NixOS firewall is on by default.** `kubectl port-forward` (localhost) needs
  no changes. Exposing a `NodePort` to the LAN requires opening the port, e.g.
  `networking.firewall.allowedTCPPorts = [ 30000 ];` — not needed for this lab's
  port-forward workflow.
- **`/persist` bootstrap mkdir.** The bind mount target
  `/persist/var/lib/rancher/k3s` must exist *before* k3s starts the first time.
  Run `sudo mkdir -p /persist/var/lib/rancher/k3s` before the first `omni-apply`
  that enables k3s. (Unlike the nvim mounts, this bind is mounted at boot — no
  `noauto`/`x-systemd.automount` — because k3s needs its state at service start
  and the k3s module lays down tmpfiles symlinks before k3s starts.)
- **Flakes read the git index.** A freshly created `labs/k8s-telemetry/nix/k3s.nix`
  is invisible to `omni-apply` until `git add`-ed. This is the #1 "my change did
  nothing" cause repo-wide.
- **Daily-driver cost.** This runs a real K8s control plane on your desktop
  (~300–600 MB RAM idle plus workloads). Disable k3s (remove the import line +
  `omni-apply`) when you're done to reclaim resources; cluster state in
  `/persist` is preserved across disable/enable cycles unless you run
  `k3s-uninstall.sh`.
- **Desktop-only.** Import only in `hosts/desktop/default.nix`. Never on `dell3440`.
- **cRPD license.** cRPD is neither on Docker Hub nor free. Never commit a
  license to git — load it as an out-of-tree `Secret` (follow the repo's secrets
  pattern at `~/.config/secrets/`). Phase 6 is entirely optional.
- **Kubeconfig permissions.** `--write-kubeconfig-mode 644` makes
  `/etc/rancher/k3s/k3s.yaml` world-readable; it holds cluster-admin creds.
  Acceptable for an isolated single-user desktop lab; tighten to `600` (and use
  sudo / a group) on a shared host.
- **gNMI target port.** `flex/frr-gnmi-target:1sec` declares no EXPOSE; 9339 is
  an assumption. Verify in Phase 2 and adjust `targetPort` + the gnmic target
  address if it listens elsewhere.
- **Image tags.** Pinned concrete `image:tag` in every manifest (not `latest`)
  — reproducibility matters even in a lab.

---

## 📚 References

- [k3s documentation](https://docs.k3s.io/) — installation, architecture, `k3s-uninstall.sh`
- [NixOS `services.k3s` options](https://search.nixos.org/options?query=services.k3s)
- [gnmic documentation](https://gnmic.openconfig.net/) — collector config, outputs (prometheus, loki), `capabilities`/`subscribe`
- [Prometheus documentation](https://prometheus.io/docs/) — scrape config, `/api/v1/targets`
- [Loki documentation](https://grafana.com/docs/loki/latest/) — `/ready`, log ingestion
- [Grafana documentation](https://grafana.com/docs/grafana/latest/) — datasource provisioning, dashboards
- [OpenConfig gNMI spec](https://github.com/openconfig/reference/tree/main/rpc/gnmi) — `Capability`, `Get`, `Subscribe` RPCs
- Repo conventions: `~/.omni-nix/WORKFLOW.md`, `~/.omni-nix/README.md`, `~/.omni-nix/CLAUDE.md`
