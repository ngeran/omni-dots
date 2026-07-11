# 🚀 Runbook — Start the K8s Telemetry Lab (end to end)

A step-by-step, copy-pasteable procedure to bring the whole lab up from zero:
k3s → gNMI target → gnmic → Prometheus → Loki → Grafana. Run on the
`nixos-btw` desktop. Every step has a **verify** block — don't move on until it
passes.

> This runbook reflects the current `nix/k3s.nix` (state bind-mounted onto
> `/persist`). If you removed that bind mount, skip the `mkdir` in Step 1.2.

---

## 0. Pre-flight checks

```bash
# 0.1 On the right host
hostname   # → nixos-btw

# 0.2 Lab CLI tools present (installed via modules/apps/dev-tools.nix)
kubectl version --client    # → Client Version: v1.36.x
k9s version                 # → Version: 0.50.x
gnmic version               # → version : 0.46.x

# 0.3 No stale k3s from a prior attempt (skip if first time)
sudo systemctl is-active k3s 2>/dev/null && echo "k3s already running — go to Step 2"
```

If any tool in 0.2 is missing, run `omni-apply` first (the tools live in
`modules/apps/dev-tools.nix`, which is always imported on the desktop).

---

## 1. Enable k3s (one-time, system-level)

k3s is gated — `labs/k8s-telemetry/nix/k3s.nix` is **not** imported by default.
This step turns it on. **Desktop only — never do this on `dell3440`.**

### 1.1 Bootstrap the persistent state dir (once)
```bash
sudo mkdir -p /persist/var/lib/rancher/k3s
```
*Why:* k3s's data dir is hardcoded to `/var/lib/rancher/k3s`; the module
bind-mounts that onto `/persist/...` (repo convention). A bind mount's source
must exist at boot time, and NixOS can't create it early enough — hence the
manual `sudo mkdir`. (One-time only.)

### 1.2 Wire the module into the desktop host
```bash
nvim ~/.omni-nix/hosts/desktop/default.nix
# add this line inside the existing `imports = [ ... ]` block:
#   ../../labs/k8s-telemetry/nix/k3s.nix
```

### 1.3 Stage + apply
```bash
git -C ~/.omni-nix add labs/k8s-telemetry/nix/k3s.nix hosts/desktop/default.nix
sudo nixos-rebuild dry-activate --flake ~/.omni-nix#nixos-btw   # sanity check (optional)
omni-apply
```

### 1.4 Make kubeconfig usable as your user
```bash
mkdir -p ~/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config     # 644 mode → readable without sudo
chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config                 # add to ~/.bashrc to persist
```

### 1.5 Verify k3s
```bash
sudo systemctl status k3s --no-pager | head -5   # → active (running)
k3s kubectl get nodes                            # → nixos-btw   Ready
kubectl get nodes                                # → same (confirms KUBECONFIG works)
```
**Expected:** one node, `Ready`. If k3s failed to start, check
`sudo journalctl -u k3s -b --no-pager | tail -40` — the usual cause is skipping
Step 1.1 (fix: `sudo mkdir -p /persist/var/lib/rancher/k3s && sudo systemctl restart k3s`).

---

## 2. Namespaces

```bash
cd ~/.omni-nix/labs/k8s-telemetry
kubectl apply -f manifests/00-namespaces.yaml
kubectl get ns                                  # → telemetry, monitoring, network, lab
```

---

## 3. gNMI target + gnmic collector

### 3.1 Apply
```bash
kubectl apply -f manifests/10-gnmi-target.yaml -f manifests/20-gnmic.yaml
kubectl -n telemetry get pods -w                # wait until both are Running
# Ctrl-C to exit -w once Running
```

### 3.2 ⚠️ Verify the gNMI target port (known open item)
The `flex/frr-gnmi-target:1sec` image declares no EXPOSE; manifests assume
**9339**. Confirm before trusting gnmic:
```bash
kubectl -n telemetry exec deploy/gnmi-target -- sh -c 'ss -ltnp 2>/dev/null || netstat -ltnp'
```
- If it shows **9339** → continue.
- If a **different** port (e.g. 50051, 57400) → edit both files and re-apply:
  ```bash
  # in manifests/10-gnmi-target.yaml: set containerPort + Service targetPort to <port>
  # in manifests/20-gnmic.yaml: set the target address to gnmi-target:<port>
  kubectl apply -f manifests/10-gnmi-target.yaml -f manifests/20-gnmic.yaml
  kubectl -n telemetry rollout restart deploy/gnmic
  ```

### 3.3 Verify the gNMI path end to end
```bash
kubectl -n telemetry exec deploy/gnmic -- \
  gnmic -a gnmi-target:9339 -u admin -p admin --insecure capabilities
```
**Expected:** a capabilities response listing the gNMI version and supported
models/paths. This proves target ↔ gnmic over gNMI.

### 3.4 Verify gnmic is exposing metrics
```bash
kubectl -n telemetry port-forward svc/gnmic 9804:9804 &
curl -s localhost:9804/metrics | head            # → Prometheus exposition lines
kill %1                                          # stop the port-forward
```

---

## 4. Prometheus

```bash
kubectl apply -f manifests/30-prometheus.yaml
kubectl -n monitoring get pods -w                # wait for Running
kubectl -n monitoring port-forward svc/prometheus 9090:9090 &
```
Open `http://localhost:9090/targets` → the **gnmic** target should be **UP**.
Or from the CLI:
```bash
curl -s localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
# → {"job":"gnmic","health":"up"}  and  {"job":"prometheus","health":"up"}
```
```bash
kill %1   # stop port-forward
```

---

## 5. Loki

```bash
kubectl apply -f manifests/40-loki.yaml
kubectl -n monitoring get pods -w                # wait for Running
kubectl -n monitoring port-forward svc/loki 3100:3100 &
curl -s localhost:3100/ready                     # → ready (may take ~30s on first start)
kill %1
```

---

## 6. Grafana

```bash
kubectl apply -f manifests/50-grafana.yaml
kubectl -n monitoring get pods -w                # wait for Running
kubectl -n monitoring port-forward svc/grafana 3000:3000 &
```
Open `http://localhost:3000` → log in (`admin` / `admin`, skip password change).
Go to **Connections → Data sources** → both **Prometheus** and **Loki** should
be present and connected (pre-provisioned).

Build a test panel: query `gnmic` metrics from Prometheus (e.g.
`interface_in_octets` or whatever the simulator exposes) — you should see live
lines from the 1-second subscription.

```bash
kill %1   # stop port-forward
```

🎉 **The full pipeline is up:** gNMI target → gnmic → Prometheus + Loki → Grafana.

---

## 7. (Optional) cRPD — real Juniper target

Only if you have a cRPD image + license. cRPD is **not** on Docker Hub and needs
a license — this is why the lab uses the free simulator above.

```bash
# 7.1 Load the license as an out-of-tree Secret (never commit it)
kubectl -n telemetry create secret generic crpd-license \
  --from-file=crpd-license.key=/path/to/juniper_license.key

# 7.2 Edit manifests/60-crpd.yaml: set image: CRPD_IMAGE:REPLACE_ME → your real image:tag
nvim manifests/60-crpd.yaml

# 7.3 Apply + point gnmic at it
kubectl apply -f manifests/60-crpd.yaml
kubectl -n telemetry exec deploy/gnmic -- \
  gnmic -a crpd:57400 -u <user> -p <pass> --insecure capabilities
```

---

## Smoke test (whole stack at a glance)

```bash
echo "=== nodes ==="        && kubectl get nodes
echo "=== all pods ==="     && kubectl get pods -A | grep -E 'telemetry|monitoring'
echo "=== services ==="     && kubectl get svc -n telemetry -n monitoring
echo "=== prometheus targets ===" && kubectl -n monitoring port-forward svc/prometheus 9090:9090 & sleep 1 && \
   curl -s localhost:9090/api/v1/targets | jq '.data.activeTargets[].health' | sort | uniq -c ; kill %1
```
All pods `Running`, all targets `up` → lab is healthy.

---

## Teardown

### Tear down the manifests (keep k3s installed)
```bash
cd ~/.omni-nix/labs/k8s-telemetry
for f in 60-crpd 50-grafana 40-loki 30-prometheus 20-gnmic 10-gnmi-target 00-namespaces; do
  kubectl delete -f manifests/$f.yaml --ignore-not-found
done
```

### Fully disable k3s
```bash
# 1. Remove the import line from hosts/desktop/default.nix
nvim ~/.omni-nix/hosts/desktop/default.nix     # delete: ../../labs/k8s-telemetry/nix/k3s.nix
git -C ~/.omni-nix add hosts/desktop/default.nix
omni-apply                                       # rebuild without k3s

# 2. (optional) wipe k3s + its state entirely
sudo /run/current-system/sw/bin/k3s-uninstall.sh 2>/dev/null || sudo /usr/local/bin/k3s-uninstall.sh
sudo rm -rf /persist/var/lib/rancher/k3s
rm -f ~/.kube/config
```
The `labs/k8s-telemetry/` files stay in the repo — with the import removed they
are inert.

---

## Troubleshooting

| Symptom | Check / Fix |
|---|---|
| `kubectl` command not found | Run `omni-apply` (tools are in `dev-tools.nix`); or use `k3s kubectl` |
| k3s won't start at boot | Likely skipped Step 1.1 → `sudo mkdir -p /persist/var/lib/rancher/k3s && sudo systemctl restart k3s` |
| `kubectl get nodes` → connection refused | k3s not up: `sudo systemctl status k3s`; or `KUBECONFIG` unset → `export KUBECONFIG=~/.kube/config` |
| Pod `ImagePullBackOff` | Check the image:tag in the manifest; `kubectl describe pod -n <ns> <pod>` for the pull error. gnmic is on **GHCR** not Docker Hub. |
| gnmic `connection refused` to target | Wrong gNMI port — redo Step 3.2 and align `targetPort` + gnmic target address |
| Prometheus target `DOWN` | `kubectl -n telemetry get pods` (gnmic Running?); `kubectl -n telemetry logs deploy/gnmic`; confirm `:9804/metrics` serves (Step 3.4) |
| Loki `/ready` not ready | First start takes ~30s; `kubectl -n monitoring logs deploy/loki` for errors; filesystem storage needs the emptyDir (auto-created) |
| Grafana datasource not connected | Cross-namespace DNS: `http://prometheus.monitoring.svc.cluster.local:9090` — verify the Service exists: `kubectl -n monitoring get svc` |
| `omni-apply` says "my change did nothing" | New file not `git add`-ed — flakes read the git index |

### Useful commands
```bash
k9s                                        # TUI over the whole cluster
kubectl -n telemetry logs -f deploy/gnmic  # live gnmic logs
kubectl -n monitoring logs -f deploy/prometheus
kubectl get events -A --sort-by=.lastTimestamp | tail   # recent cluster events
sudo journalctl -u k3s -f                  # live k3s daemon logs
```

---

## Quick reference — what runs where

| Component | Namespace | Service:port | Image |
|---|---|---|---|
| gNMI target | telemetry | gnmi-target:9339 | flex/frr-gnmi-target:1sec |
| gnmic | telemetry | gnmic:9804 | ghcr.io/openconfig/gnmic:0.46.0 |
| Prometheus | monitoring | prometheus:9090 | prom/prometheus:v3.12.0 |
| Loki | monitoring | loki:3100 | grafana/loki:3.5.1 |
| Grafana | monitoring | grafana:3000 | grafana/grafana:11.6.16 |
| cRPD (opt) | telemetry | crpd:57400 | bring-your-own |

Port-forwards (`kubectl -n <ns> port-forward svc/<name> <local>:<port>`) are
localhost-only and need no firewall changes.

---

## 🔌 Cluster networking (reference)

### The fabric — k3s built-in, already working, no config needed
- **CNI:** flannel (VXLAN), bundled with k3s. Pod CIDR `10.42.0.0/16` (set in `nix/k3s.nix`).
- **Service CIDR:** `10.43.0.0/16`. Every Service gets a stable `10.43.x.x` ClusterIP.
- **DNS:** CoreDNS. Services resolve as `<svc>.<ns>.svc.cluster.local` (short form `<svc>.<ns>`). This is exactly how the manifests wire together:
  - gnmic → `gnmi-target:9339` (same namespace → short name)
  - Prometheus → `gnmic.telemetry.svc.cluster.local:9804` (cross-namespace FQDN)
  - Grafana → `prometheus.monitoring.svc.cluster.local:9090` and `loki.monitoring.svc.cluster.local:3100`
- **CIDR conflict check:** your LAN is `10.0.0.0/24` (desktop `10.0.0.86` on wifi). Pod/service CIDRs (`10.42/16`, `10.43/16`) do **not** overlap — ✅ safe.

### Egress (pods → internet/LAN) — automatic
Pods NAT through the node's IP (`10.0.0.86`). That's why `kubectl apply` pulls images from Docker Hub / GHCR with zero extra config.

### Ingress (LAN → pods) — you must wire this yourself
Every Service in this lab is `ClusterIP` by default — reachable **only inside the cluster**. To reach one from the LAN (another machine, or Pihole as network DNS), change its Service `type` and open the firewall:

| Method | Use when | Reachable at | Firewall |
|---|---|---|---|
| `port-forward` (current) | Personal/ephemeral, localhost | `localhost:<port>` on the desktop | none |
| `NodePort` | Quick LAN access for HTTP | `10.0.0.86:30000-32767` | open that TCP port |
| `LoadBalancer` | Stable LAN IP per service — **Klipper is still enabled** (only traefik was disabled), so this works single-node without MetalLB | `10.0.0.86:<port>` | open that port |
| `hostNetwork` (Pihole) | Pihole binding the node's NIC on :53/:80 | `10.0.0.86:53` / `:80` | open 53 (udp+tcp), 80 |
| Ingress (re-enable traefik) | Hostnames (`grafana.lab.local`) — HTTP only, **not** DNS | `10.0.0.86:80/443` | open 80/443 |

### Firewall — the gotcha
NixOS firewall is **on by default** and k3s opens **no** ports for you. Any LAN-facing method above needs the port opened in NixOS, e.g. add to `hosts/desktop/default.nix` (or a module):
```nix
networking.firewall.allowedTCPPorts = [ 30090 ];   # a NodePort for Grafana
networking.firewall.allowedUDPPorts = [ 53 ];      # Pihole DNS (also allow TCP 53)
```
`port-forward` (localhost) needs no firewall change.

### Concrete: expose Grafana to the LAN
Edit the Service in `manifests/50-grafana.yaml`:
```yaml
spec:
  type: NodePort          # or LoadBalancer — Klipper gives it 10.0.0.86
  ports:
    - name: web
      port: 3000
      targetPort: 3000
      nodePort: 30090     # NodePort only; range 30000-32767
```
Then open `30090` in the NixOS firewall (`omni-apply`), `kubectl apply -f manifests/50-grafana.yaml`, and browse to `http://10.0.0.86:30090` from any LAN device.

### Pihole specifically
Pihole must be LAN-reachable as DNS — `port-forward` **cannot** do this. Use either:
- **`hostNetwork: true`** on the Pihole pod — binds `10.0.0.86:53/80` directly; simplest, one pod; or
- **`type: LoadBalancer`** with MetalLB for a dedicated stable IP (e.g. `10.0.0.53`) if you want Pihole on its own IP rather than sharing the desktop's.

Either way, open firewall ports **53 (udp+tcp)** and **80**.
