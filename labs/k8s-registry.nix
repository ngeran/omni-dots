# =============================================================================
# Local container registry — fast dev -> k3s deploy loop (no sudo per iteration)
# =============================================================================
#
# WHAT THIS IS
#   A registry:2 container bound to 127.0.0.1:5000, plus a k3s registries.yaml
#   that teaches k3s's containerd to pull "localhost:5000" over plain HTTP.
#   Together this lets a workflow like nutils/deploy.sh do:
#       docker build -t localhost:5000/nutils:<tag> .
#       docker push localhost:5000/nutils:<tag>        # no sudo (docker group)
#       kubectl set image deployment/nutils ...         # k3s pulls over HTTP
#   with NO `docker save | sudo k3s ctr images import` step — the slow, sudo-gated
#   loop that the earlier pyapp deploy used.
#
# WHY LOCALHOST-ONLY
#   Bound to 127.0.0.1 so it is reachable from host docker (push) and from k3s
#   (pull — k3s runs on the host) but NOT exposed to the LAN. No firewall opening,
#   no TLS, no insecure-registries change needed (Docker trusts localhost by default).
#
# ACTIVATION
#   This module is opt-in (imported in hosts/desktop/default.nix). After the first
#   `omni-apply` that adds it, restart k3s so containerd reads registries.yaml:
#       sudo systemctl restart k3s
#   Verify:  curl -s localhost:5000/v2/   ->   {}
#
# GOTCHAS
#   - Docker must be enabled (it is — modules/apps/virtualization.nix). oci-containers
#     auto-uses the docker backend when docker is enabled.
#   - If a `docker push localhost:5000/...` ever complains about HTTPS, add
#     `daemon.settings.insecure-registries = [ "localhost:5000" ];` to
#     modules/apps/virtualization.nix (normally not needed — localhost is trusted).
#   - Flakes read the git index: `git add` this file or omni-apply ignores it.
# =============================================================================

{ ... }:

{
  # 1. The registry container — localhost-only, persistent volume, auto-starts.
  #    Pin the backend explicitly (docker is enabled in virtualization.nix).
  virtualisation.oci-containers.backend = "docker";
  virtualisation.oci-containers.containers.registry = {
    image = "registry:2";
    ports = [ "127.0.0.1:5000:5000" ];
    autoStart = true;
    volumes = [ "registry-data:/var/lib/registry" ]; # named volume -> survives restarts
  };

  # 2. Tell k3s's containerd to pull localhost:5000 over plain HTTP (no TLS).
  #    k3s reads /etc/rancher/k3s/registries.yaml at service start.
  environment.etc."rancher/k3s/registries.yaml".text = ''
    mirrors:
      "localhost:5000":
        endpoint:
          - "http://127.0.0.1:5000"
  '';
}
