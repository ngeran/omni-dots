---
name: nixos
description: NixOS and flake changes, module writing, rebuild optimization. Load for any .nix file, flake input, or nixos-rebuild task.
---

## Rules
- Never invent options. Verify with `nixos-option <path>` or search.nixos.org
  before use.
- Validate in this order: `nix flake check`, then
  `nixos-rebuild dry-build --flake .#host`. Never run `switch` without explicit
  user approval.
- Prefer small modules with `lib.mkEnableOption` + `lib.mkIf cfg.enable`.
- Use `lib.mkDefault` for overridable defaults, `lib.mkForce` only with a
  comment explaining why.
- Optimization checklist: `nix-store --gc` / `nix.gc.automatic`,
  `nix.settings.auto-optimise-store`, `nix.settings.max-jobs`, binary caches,
  trim `environment.systemPackages`, `nix-tree` / `nix path-info -Sh` to find
  closure bloat.
- Always give complete files, never partial diffs.
