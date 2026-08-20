# =========================================================================
# Ollama — local LLM inference (CUDA, RTX 5080)
# =========================================================================
# Extracted from modules/nvidiagpu-compute.nix (which keeps only the driver /
# CUDA-tooling half). Tuned for ONE target workload:
#     Qwen2.5-Coder-32B (quantized) as a local coding assistant.
# Model blobs live on /mnt/INLAND-500GB (root SSD stays lean) — see the
# storage plumbing section at the bottom for why that needs a static user.
#
# VRAM budget reality check (RTX 5080 = 16 GB):
#   qwen2.5-coder:32b           Q4_K_M  ≈ 20 GB weights — the registry default
#                               tag ("32b" IS instruct + Q4_K_M). Does NOT fully
#                               fit; Ollama auto-offloads some layers to system
#                               RAM (fast DDR5 here) and still gives usable
#                               tokens/s. Best quality-per-bit quantization.
#   32b-instruct-q3_K_M         ≈ 16 GB — more layers on-GPU (faster), but a
#                               noticeably weaker quant for CODE (Q3 starts
#                               breaking indentation/bracket discipline).
#   If speed ever matters more than 32B quality: qwen2.5-coder:14b (Q4_K_M ≈ 9 GB)
#   fits ENTIRELY in VRAM and flies.
# The env vars below are what make a 32B workable on 16 GB — don't drop them.
# =========================================================================
{ config, lib, pkgs, ... }:

{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;   # CUDA build (unfree) — Blackwell sm_120 works on 0.32.x

    # --- Model storage lives on INLAND, not the root SSD -------------------
    # A 32B quant is ~20 GB of blobs; /var/lib (root nvme) shouldn't carry that.
    # The module auto-adds this path to the unit's ReadWritePaths.
    models = "/mnt/INLAND-500GB/ollama/models";

    # --- Static user — REQUIRED for the custom models path ------------------
    # Upstream runs the daemon as a DynamicUser (transient UID from the
    # recyclable 61184-65519 range, UMask 0077). That's safe only for paths
    # systemd manages via StateDirectory= (/var/lib/ollama). Blobs written to
    # a path OUTSIDE it would be owned by a UID that may belong to a DIFFERENT
    # unit after the next reboot (explicitly warned about in systemd.exec(5)).
    # Naming a user makes it static: the module creates `ollama`/`ollama` in
    # the user db, and per systemd "if a statically allocated user of the
    # configured name already exists, it is used and no dynamic user/group is
    # allocated" — stable UID, stable ownership on the INLAND ext4 disk.
    user = "ollama";
    group = "ollama";

    # Pulled automatically by `ollama-model-loader.service` the first time
    # ollama.service starts (~20 GB download; afterwards it's a no-op check).
    #   • qwen2.5-coder:32b — the main model (agent/deep work)
    #   • nomic-embed-text — 274 MB embedding model for Open WebUI RAG
    #     (RAG_EMBEDDING_ENGINE=ollama in modules/open-webui.nix). Runs
    #     mostly on CPU-class compute; ~0.5 GB VRAM while resident.
    loadModels = [
      "qwen2.5-coder:32b"
      "nomic-embed-text"
    ];
    # syncModels stays false — we only DECLARATIVELY pull, never auto-delete
    # models that were `ollama pull`-ed by hand.

    environmentVariables = {
      # Flash attention: faster long-context attention on CUDA, and REQUIRED
      # for the KV-cache quantization below to take effect.
      OLLAMA_FLASH_ATTENTION = "1";

      # 8-bit KV cache: halves KV VRAM vs f16 with negligible quality loss.
      # For this model KV costs ≈ 128 KB/token → ~2 GB @ 16k context instead
      # of ~4 GB. This is the single biggest "fits on the card" lever.
      OLLAMA_KV_CACHE_TYPE = "q8_0";

      # Qwen2.5-Coder natively supports 32k (128k with YaRN). 16k is the
      # sweet spot: roomy enough for real files in context, while KV stays
      # ~2 GB so more weight layers stay on-GPU. Raise to 32768 only if you
      # accept more CPU offload (≈ +2 GB KV).
      OLLAMA_CONTEXT_LENGTH = "16384";

      # One request slot: each parallel slot duplicates the KV cache.
      OLLAMA_NUM_PARALLEL = "1";
      # TWO resident models — LLM + embedding. This is REQUIRED for RAG: with
      # 1, every embedding request (each Open WebUI knowledge query) would
      # EVICT the resident coder model and force a ~20 GB reload. The embed
      # model is ~0.5 GB, so the cost is a sliver of the 32B's GPU layers.
      OLLAMA_MAX_LOADED_MODELS = "2";

      # Default is 5m — too eager for an on-demand daemon you start
      # deliberately. Keep the model resident for a working session instead
      # of re-loading ~20 GB from disk after every coffee break.
      OLLAMA_KEEP_ALIVE = "1h";
    };
  };

  # On-demand: do NOT auto-start ollama at boot (mirrors the k3s pattern in
  # labs/k8s-telemetry/nix/k3s.nix). The CUDA daemon inits the GPU on startup —
  # wasted boot time + idle GPU memory on a daily driver when you're not doing
  # local AI. Start it when you sit down to use it:
  #     sudo systemctl start ollama      # also pulls/verifies the model (loader unit)
  #     sudo systemctl stop ollama       # frees the VRAM
  systemd.services.ollama.wantedBy = lib.mkForce [ ];

  # The upstream module wires ollama-model-loader with
  #   wantedBy = [ "multi-user.target" "ollama.service" ]  +  bindsTo ollama
  # and bindsTo PULLS ollama.service into the boot transaction via the
  # multi-user.target alias — silently re-enabling autostart. Drop the
  # multi-user alias so the loader fires only when ollama itself is started.
  # (The loader only runs the `ollama` CLI against 127.0.0.1:11434 — the
  # SERVER does all blob writes, so it needs no INLAND access of its own.)
  systemd.services.ollama-model-loader.wantedBy = lib.mkForce [ "ollama.service" ];

  # =========================================================================
  # Storage plumbing for the INLAND models dir
  # =========================================================================
  # Two traps, both hit in practice while wiring this up:
  #  1) /mnt/INLAND-500GB is owned by nikos — systemd-tmpfiles REFUSES to
  #     create ollama-owned dirs under a non-root-owned parent ("Detected
  #     unsafe path transition": anti-dir-planting guard), so tmpfiles rules
  #     can't build this chain.
  #  2) ollama.service names this path in ReadWritePaths, and systemd builds
  #     (and validates!) the unit's mount namespace BEFORE running ANY of its
  #     commands — even "+"-prefixed ExecStartPre died with 226/NAMESPACE
  #     while the path was missing. Nothing inside the unit can create it.
  # => a SEPARATE sandbox-free oneshot unit. `systemctl start ollama` pulls
  #    it in via the ollama.service.wants symlink and ordering (before=)
  #    makes it complete first, so the path exists by the time ollama's
  #    namespace is validated. Idempotent; self-heals after a disk wipe.
  #    (mkdir/chown through a nikos-planted symlink would redirect the blob
  #    store — irrelevant on this single-admin box, where the only user is
  #    wheel.)
  systemd.services.ollama-models-dir = {
    description = "Prepare /mnt/INLAND-500GB/ollama/models for ollama.service";
    wantedBy = [ "ollama.service" ];
    before = [ "ollama.service" ];
    # Don't run (and don't create a shadow dir on the root fs) if INLAND
    # isn't mounted — same nofail rationale as ollama.service's own gate.
    unitConfig.RequiresMountsFor = [ "/mnt/INLAND-500GB" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = with pkgs; [ coreutils ];
    script = ''
      mkdir -p /mnt/INLAND-500GB/ollama/models
      chown ollama:ollama /mnt/INLAND-500GB/ollama /mnt/INLAND-500GB/ollama/models
      chmod 0750 /mnt/INLAND-500GB/ollama /mnt/INLAND-500GB/ollama/models
    '';
  };

  # INLAND mounts with `nofail` (hosts/desktop/default.nix) — if the disk is
  # ever absent, don't let ollama start and write into the empty mountpoint
  # hole on the root fs. RequiresMountsFor derives the mnt-INLAND\x2d500GB
  # .mount unit from the path and adds Requires= + After= for it: with the
  # disk missing, `systemctl start ollama` fails cleanly instead.
  systemd.services.ollama.unitConfig.RequiresMountsFor =
    [ "/mnt/INLAND-500GB/ollama/models" ];
}
