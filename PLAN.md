# PLAN — Remove local k3s/Kubernetes (cluster moves to a separate server)

Scope agreed with Nikos (2026-11-13):
- Delete the local cluster: k3s module, registry module, the whole `labs/` tree.
- Templates: **strip k8s deploy** — keep devShells + `nix build .#image` +
  `run`/`check`/`test` (local docker smoke). Delete `manifests/` and the
  push/deploy/doctor/logs/forward recipes.
- Docker stays boot-started (no behavior change).
- Remove client packages: kubectl, k9s, gnmic, skopeo. Keep `just`.
- Docs stay in sync (README + CLAUDE.md must match reality).

## Steps

- [x] 1. Delete `labs/` (`git rm -r labs` — k3s.nix, k8s-registry.nix, k8s-telemetry/).
- [x] 2. `hosts/desktop/default.nix`: remove the two lab imports; fix the
       boot-speed comment (no longer "registry listens :5000 / k3s on-demand").
- [x] 3. `modules/apps/dev-tools.nix`: drop kubectl/k9s/gnmic section and
       skopeo; keep `just`; rewrite section comments.
- [x] 4. `modules/apps/programming.nix`: remove `KUBECONFIG` session variable.
- [x] 5. Comment-only fixes: `virtualization.nix` (registry rationale),
       `ollama.nix` ("mirrors the k3s pattern"), `core/default.nix` (BBR
       "helps the registry, k3s pulls").
- [x] 6. Templates python/hugo/react/astro: rewrite justfile (keep
       build/run/check/test), strip skopeo/kubectl from template devShells,
       fix flake.nix comments/imageName, `git rm -r` each `manifests/`.
       Check `templates/python/README.md` + `.envrc` files.
- [x] 7. Root `flake.nix`: update templates comment block + descriptions.
- [x] 8. Docs: update `README.md`, delete `PIPELINEv3.md`, fix references in
       `DEV-ENVIRONMENTS.md`, `WORKFLOW.md`, `CLEAN-INSTALL.md`, `CLAUDE.md`.
- [x] 9. Verify: stage ALL touched files (flakes evaluate from the git index
       — versions.json stays unstaged, unrelated), then
       `nix flake check` + grep for leftover k3s/k8s/kubectl/skopeo refs +
       `nix build .#nixosConfigurations.nixos-btw.config.system.build.toplevel`
       + reviewer subagent on the diff.

## Manual follow-ups after `omni-apply` (runtime state, not in the flake)

- `/persist/var/lib/rancher/k3s` — old k3s state (~GBs); `sudo rm -r` when
  confident (machine reboots fine without it).
- `~/.kube/config`, stray stopped registry containers (`docker ps -a |
  grep registry`), old images (`docker image prune`).
