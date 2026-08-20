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

      # Default model for the agent AND the small background tasks (titles,
      # summaries). Same model on purpose: MAX_LOADED_MODELS=1 on the server,
      # so a second "small" model would just evict the big one.
      model = "ollama/${model}";
      small_model = "ollama/${model}";

      provider.ollama = {
        # OpenAI-compatible provider shim from the AI SDK — the documented
        # way to wire any /v1 endpoint (Ollama serves one natively).
        npm = "@ai-sdk/openai-compatible";
        name = "Ollama (local)";
        options.baseURL = ollamaBase;
        models."${model}" = {
          name = "Qwen2.5 Coder 32B (local)";
          # Qwen2.5-Coder-instruct does native tool calls — required for
          # opencode's agentic edits/shell tools.
          tool_call = true;
          # Keep the agent honest about the server-side window
          # (OLLAMA_CONTEXT_LENGTH=16384 in modules/ollama.nix; Qwen2.5
          # generates up to 8k tokens per response).
          limit = {
            context = 16384;
            output = 8192;
          };
        };
      };
    };
  };
}
