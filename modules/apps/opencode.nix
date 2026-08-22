# modules/apps/opencode.nix
# OpenCode — open-source AI coding agent for the terminal (opencode.ai),
# pointed at the LOCAL Ollama daemon (modules/ollama.nix) running
# qwen2.5-coder:32b. No cloud provider, no API key — everything stays on the
# 5080. This module is Home-Manager level (user CLI), mirroring claude.nix.
{ pkgs, lib, ... }:

let
  isSupported = pkgs.stdenv.hostPlatform.system == "x86_64-linux";

  # Ollama's OpenAI-compatible endpoint. 127.0.0.1, not "localhost" — ollama
  # binds 127.0.0.1:11434 only, and on this box `localhost` may resolve to
  # ::1 first, which would refuse the connection.
  ollamaBase = "http://127.0.0.1:11434/v1";
in
{
  config = lib.mkIf isSupported {
    # 1. Install the CLI (nixpkgs — pinned with the rest of the system),
    #    plus node — the MCP servers below are npm-distributed and launch
    #    through npx by absolute store path (no PATH dependence).
    home.packages = [
      pkgs.opencode
      pkgs.nodejs
    ];

    # 2. Shell alias, mirroring `c`/`cc` for claude.
    home.shellAliases = {
      oc = "opencode";
    };

    # 3. Config — deployed as a SINGLE FILE so ~/.config/opencode/ stays a
    # real writable directory (opencode writes AGENTS.md etc. next to it;
    # auth/state live in ~/.local/share/opencode). Same per-file pattern as
    # the hypr configs in home/dotfiles.nix.
    # ($schema needs quoting — $ isn't legal in a bare Nix identifier.)
    xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";

      # Nix owns the binary — never let it self-update underneath the profile.
      autoupdate = false;

      # Default agent model: the anti-loop 14B variant. The qwen2.5-CODER
      # models (14b/32b) are deliberately NOT declared here — they cannot
      # emit structured tool_calls through this Ollama build (probed
      # 2026-08-21: bare JSON as text) and will narrate tool calls forever
      # instead of executing them. Base qwen2.5:14b tool-calls correctly.
      # Judgment-heavy work: switch per-session to zai-coding-plan/glm-5.x.
      model = "ollama/qwen2.5:14b-agent";

      # Background housekeeping (titles, anchored session summaries) goes to
      # a cheap CLOUD model on purpose: opencode runs a summarizer subagent
      # after every turn, and on a local model that meta-task is slow AND
      # flaky (observed: the 14B re-summarizing in circles after the real
      # answer already landed — turns look "hung"). glm-5-turbo does it in
      # ~1s on the coding plan. NOTE: this means even local-model sessions
      # send a derived summary to Z.ai — fine here (cloud is already in the
      # ladder), flip to an ollama model if a session must stay fully local.
      small_model = "zai-coding-plan/glm-5-turbo";

      provider.ollama = {
        # OpenAI-compatible provider shim from the AI SDK — the documented
        # way to wire any /v1 endpoint (Ollama serves one natively).
        npm = "@ai-sdk/openai-compatible";
        name = "Ollama (local)";
        options.baseURL = ollamaBase;
        # BOTH local coders, so /models can switch between them:
        #   32b — deep work (partially CPU-offloaded, slow agent rounds)
        #   14b — mechanical edits (fits fully in VRAM, ~7x faster rounds)
        # NOTE: no `temperature` here — opencode 1.15 validates per-model
        # temperature as BOOLEAN (a newer schema allows numbers, the
        # installed one doesn't — deploying 0.5 broke opencode startup with
        # SchemaError). The anti-loop decoding params (temperature +
        # repeat_penalty) live server-side in the 14b-agent Modelfile
        # variant, see ollama-model-variants.service in modules/ollama.nix.
        # Only tool-CAPABLE models declared (see the coder caveat above the
        # default `model` setting) — opencode agents are useless without
        # structured tool_calls.
        models = {
          "qwen2.5:14b" = {
            name = "Qwen2.5 14B (local, base)";
            tool_call = true;
            limit.context = 32768;
            limit.output = 8192;
          };
          # Anti-loop variant: same weights + temperature 0.6 +
          # repeat_penalty 1.15 baked in via Modelfile
          # (ollama-model-variants.service in modules/ollama.nix keeps it
          # existing; probed: structured tool_calls survive the params).
          "qwen2.5:14b-agent" = {
            name = "Qwen2.5 14B (local, anti-loop agent)";
            tool_call = true;
            limit.context = 32768;
            limit.output = 8192;
          };
        };

      # ── Free-tier MCP servers ─────────────────────────────────────────
      # (local = opencode spawns the command; first call npx-downloads the
      # package into ~/.npm — a few seconds once, cached after)
      #
      # context7: current library docs (FastAPI, Tailwind, PyEZ…) injected
      # into prompts — attacks the stale-training-data hallucinations that
      # small local models are worst at. Keyless on the free tier
      # (rate-limited; set an API key via `environment` if ever needed).
      mcp.context7 = {
        type = "local";
        command = [ "${pkgs.nodejs}/bin/npx" "-y" "@upstash/context7-mcp" ];
        enabled = true;
      };
      # sequential-thinking: structured plan-then-act scaffold — reported
      # to help small models commit to an action sequence instead of
      # orbiting. Official reference server, no config.
      mcp.sequential-thinking = {
        type = "local";
        command = [ "${pkgs.nodejs}/bin/npx" "-y" "@modelcontextprotocol/server-sequential-thinking" ];
        enabled = true;
      };
      };
    };
  };
}
