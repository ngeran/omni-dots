# 🧊 k3s Telemetry Lab — Cheat Sheet

> Condensed quick-reference for **starting, deploying, and managing** the lab.
> For the full phased procedure + troubleshooting, see **[`RUNBOOK.md`](./RUNBOOK.md)**;
> for architecture & assumptions, see **[`README.md`](./README.md)**.
>
> Host: **`nixos-btw`** (desktop only — never `dell3440`). Lab dir: `~/.omni-nix/labs/k8s-telemetry`.
> `omni-apply` = `sudo nixos-rebuild switch --flake ~/.omni-nix#nixos-btw`.
> Flakes read the **git index** → `git add` before every apply.

---

## 🟢 START — enable k3s (one-time, system level)

k3s module is inert until imported.

```bash
sudo mkdir -p /persist/var/lib/rancher/k3s        # ONCE, before first start (bind-mount source must exist)
$EDITOR ~/.omni-nix/hosts/desktop/default.nix     # add to imports = [ ... ]:
                                                  #   ../../labs/k8s-telemetry/nix/k3s.nix
git -C ~/.omni-nix add labs/k8s-telemetry/nix/k3s.nix hosts/desktop/default.nix
omni-apply

# kubeconfig (default file is root-only; the module writes it mode 644):
mkdir -p ~/.kube && cp /etc/rancher/k3s/k3s.yaml ~/.kube/config && chmod 600 ~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc && export KUBECONFIG=~/.kube/config
kubectl get nodes                                  # → nixos-btw   Ready
```

---

## 🚀 DEPLOY — apply manifests in order

```bash
cd ~/.omni-nix/labs/k8s-telemetry
kubectl apply -f manifests/                        # all at once (00→50), OR phase by phase:
# kubectl apply -f manifests/00-namespaces.yaml
# kubectl apply -f manifests/10-gnmi-target.yaml -f manifests/20-gnmic.yaml
# kubectl apply -f manifests/30-prometheus.yaml -f manifests/40-loki.yaml -f manifests/50-grafana.yaml
kubectl get pods -A | grep -E 'telemetry|monitoring'   # all Running
```

`60-crpd.yaml` is **optional / bring-your-own** (cRPD image + license) — skip unless you have one.

⚠️ **Verify the gNMI port once** (`flex/frr-gnmi-target` declares no EXPOSE; manifests assume **9339**):

```bash
kubectl -n telemetry exec deploy/gnmi-target -- sh -c 'ss -ltnp || netstat -ltnp'
# not 9339? → fix containerPort/targetPort in 10-gnmi-target.yaml + target addr in 20-gnmic.yaml, re-apply
```

---

## 🔭 Reach the UIs (port-forwards — localhost, no firewall change)

```bash
kubectl -n monitoring port-forward svc/prometheus 9090:9090   # → http://localhost:9090/targets (gnmic UP)
kubectl -n monitoring port-forward svc/loki       3100:3100   # → curl -s localhost:3100/ready  == ready
kubectl -n monitoring port-forward svc/grafana    3000:3000   # → http://localhost:3000  admin/admin
kubectl -n telemetry  port-forward svc/gnmic      9804:9804   # → curl -s localhost:9804/metrics
```

End-to-end gNMI proof:

```bash
kubectl -n telemetry exec deploy/gnmic -- gnmic -a gnmi-target:9339 -u admin -p admin --insecure capabilities
```

---

## 🛠️ MANAGE — day-2

```bash
k9s                                                  # TUI over the whole cluster (best for browsing)
kubectl get pods,svc -A                              # everything
kubectl -n telemetry  get pods -w                    # watch a namespace
kubectl -n telemetry  logs -f deploy/gnmic           # live logs
kubectl -n monitoring logs -f deploy/prometheus
kubectl -n telemetry  rollout restart deploy/gnmic   # restart after a config change
kubectl -n telemetry  exec -it deploy/gnmic -- sh    # shell into a pod
kubectl get events -A --sort-by=.lastTimestamp | tail   # recent cluster events
sudo journalctl -u k3s -f                            # the k3s daemon itself
kubectl delete pod -n telemetry <pod>                # force-recreate a pod
```

---

## 🧹 TEARDOWN — three levels

```bash
cd ~/.omni-nix/labs/k8s-telemetry

# 1) manifests only (keep k3s):
for f in 60-crpd 50-grafana 40-loki 30-prometheus 20-gnmic 10-gnmi-target 00-namespaces; do
  kubectl delete -f manifests/$f.yaml --ignore-not-found
done

# 2) disable k3s on the host (state in /persist is preserved):
$EDITOR ~/.omni-nix/hosts/desktop/default.nix       # remove: ../../labs/k8s-telemetry/nix/k3s.nix
git -C ~/.omni-nix add hosts/desktop/default.nix && omni-apply

# 3) nuke k3s + state entirely:
sudo /run/current-system/sw/bin/k3s-uninstall.sh 2>/dev/null || sudo /usr/local/bin/k3s-uninstall.sh
sudo rm -rf /persist/var/lib/rancher/k3s ; rm -f ~/.kube/config
```

---

## ⚠️ NixOS-specific traps

| Trap | Fix |
|---|---|
| "my change did nothing" | new/edited files invisible until `git add` (flakes read the git index) |
| k3s won't start at boot | skipped the `/persist` mkdir → `sudo mkdir -p /persist/var/lib/rancher/k3s && sudo systemctl restart k3s` |
| `kubectl: connection refused` | k3s down (`sudo systemctl status k3s`) or `KUBECONFIG` unset |
| Pod `ImagePullBackOff` | **gnmic is on GHCR** (`ghcr.io/openconfig/gnmic`), not Docker Hub; `kubectl describe pod` |
| Reach a svc from the LAN | `port-forward` = localhost only. `NodePort`/`LoadBalancer` need `networking.firewall.allowedTCPPorts` + `omni-apply` (Klipper LB is still on; only traefik is off) |
| Shared host | `--write-kubeconfig-mode 644` makes `/etc/rancher/k3s/k3s.yaml` world-readable — fine for a single-user desktop, tighten on shared hosts |

---

## 📍 What runs where

| Component | Namespace | Service:port | Image |
|---|---|---|---|
| gNMI target | telemetry | `gnmi-target:9339` | `flex/frr-gnmi-target:1sec` |
| gnmic | telemetry | `gnmic:9804` | `ghcr.io/openconfig/gnmic:0.46.0` |
| Prometheus | monitoring | `prometheus:9090` | `prom/prometheus:v3.12.0` |
| Loki | monitoring | `loki:3100` | `grafana/loki:3.5.1` |
| Grafana | monitoring | `grafana:3000` | `grafana/grafana:11.6.16` |
| cRPD *(opt)* | telemetry | `crpd:57400` | bring-your-own |

Pod CIDR `10.42.0.0/16`, Service CIDR `10.43.0.0/16` (no overlap with LAN `10.0.0.0/24`).
DNS: `<svc>.<ns>.svc.cluster.local`. Tools (`kubectl`, `k9s`, `gnmic`) ship via `modules/apps/dev-tools.nix`.
