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
  model = "qwen2.5-coder:32b";
in
{
  config = lib.mkIf isSupported {
    # 1. Install the CLI (nixpkgs — pinned with the rest of the system).
    home.packages = [ pkgs.opencode ];

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

      # Default model for the agent: the local 32B (switch per-session with
      # /models — 14B for mechanics, zai-coding-plan/glm-5.x for judgment).
      model = "ollama/${model}";

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
        models = {
          "qwen2.5-coder:32b" = {
            name = "Qwen2.5 Coder 32B (local, deep)";
            # Qwen2.5-Coder-instruct does native tool calls — required for
            # opencode's agentic edits/shell tools.
            tool_call = true;
            # Keep the agent honest about the server-side window
            # (OLLAMA_CONTEXT_LENGTH in modules/ollama.nix; Qwen2.5
            # generates up to 8k tokens per response).
            limit.context = 32768;
            limit.output = 8192;
          };
          "qwen2.5-coder:14b" = {
            name = "Qwen2.5 Coder 14B (local, fast)";
            tool_call = true;
            limit.context = 32768;
            limit.output = 8192;
          };
          # Anti-loop variant: same weights + temperature 0.6 +
          # repeat_penalty 1.15 baked in via Modelfile
          # (ollama-model-variants.service in modules/ollama.nix keeps it
          # existing). Use this one for agent work, not the base 14b.
          "qwen2.5-coder:14b-agent" = {
            name = "Qwen2.5 Coder 14B (local, anti-loop)";
            tool_call = true;
            limit.context = 32768;
            limit.output = 8192;
          };
        };
      };
    };
  };
}
