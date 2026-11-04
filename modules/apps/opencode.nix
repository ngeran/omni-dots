# modules/apps/opencode.nix
# OpenCode — open-source AI coding agent for the terminal (opencode.ai).
# Default model = the LOCAL Ollama daemon (modules/ollama.nix, qwen2.5:14b
# variants on the 5080); background summarization + the on-demand cloud tier
# = the z.ai coding plan via its Anthropic-compatible gateway, authenticated
# from ~/.config/secrets/zai_key — the ONE location every Z.ai key reference
# points at (Claude Code's configure-claude activation script in
# modules/apps/essentials.nix reads the same file). This module is
# Home-Manager level (user CLI), mirroring claude.nix.
{ inputs, pkgs, lib, ... }:

let
  isSupported = pkgs.stdenv.hostPlatform.system == "x86_64-linux";

  # Ollama's OpenAI-compatible endpoint. 127.0.0.1, not "localhost" — ollama
  # binds 127.0.0.1:11434 only, and on this box `localhost` may resolve to
  # ::1 first, which would refuse the connection.
  ollamaBase = "http://127.0.0.1:11434/v1";

  # opencode from UNSTABLE (2026-11-04, same pattern as modules/matugen.nix):
  # the z.ai coding-plan gateway REJECTS requests with "OpenCode 1.18.0 or
  # newer is required to use the free tier" — a client-version gate on the
  # endpoint (auth itself passes; see ~/.local/share/opencode/log). The
  # release-26.05 pin ships 1.15.10, which silently fails every Z.ai call
  # (turns look hung — the error only lands in the log, not the UI). Unstable
  # ships 1.18.29, binary-cached on cache.nixos.org.
  pkgs-unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  config = lib.mkIf isSupported {
    # 1. Install the CLI (nixpkgs — pinned with the rest of the system),
    #    plus node — the MCP servers below are npm-distributed and launch
    #    through npx by absolute store path (no PATH dependence).
    home.packages = [
      pkgs-unstable.opencode
      pkgs.nodejs
    ];

    # 2. Shell alias, mirroring `c`/`cc` for claude.
    home.shellAliases = {
      oc = "opencode";
    };

    # 4. Z.ai API key for the gateway provider below (section 3). Same
    #    convention as CONTEXT7_API_KEY in modules/apps/programming.nix:
    #    sessionVariables values are baked into the world-readable store, so
    #    the key itself is read from ~/.config/secrets/zai_key at shell
    #    startup and only lives in the process env. Dedicated var name on
    #    purpose — ANTHROPIC_AUTH_TOKEN is deliberately NOT exported (Claude
    #    Code's settings.json is its sole source; see essentials.nix →
    #    configure-claude).
    programs.bash.initExtra = ''
      [ -f "$HOME/.config/secrets/zai_key" ] && \
        export ZAI_API_KEY="$(tr -d '\n\r ' < "$HOME/.config/secrets/zai_key")"
    '';

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
      # answer already landed — turns look "hung"). NOTE: this means even
      # local-model sessions send a derived summary to Z.ai — fine here
      # (cloud is already in the ladder), flip to an ollama model if a
      # session must stay fully local.
      #
      # Was "zai-coding-plan/glm-5-turbo" (models.dev catalog provider,
      # authenticated via ZHIPU_API_KEY env or auth.json) — NEITHER existed
      # on this box, so every summarizer call was failing silently. Routed
      # through our own gateway provider below instead.
      small_model = "zai-gateway/glm-5.3-flash[1m]";

      provider.ollama = {
        # OpenAI-compatible provider shim from the AI SDK — the documented
        # way to wire any /v1 endpoint (Ollama serves one natively).
        npm = "@ai-sdk/openai-compatible";
        name = "Ollama (local)";
        # Note: opencode 1.15+ uses the 'options' block for the base SDK config.
        options.baseURL = ollamaBase;

        # BOTH local coders, so /models can switch between them:
        #   32b — deep work (partially CPU-offloaded, slow agent rounds)
        #   14b — mechanical edits (fits fully in VRAM, ~7x faster rounds)
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
        }; # models
      }; # provider.ollama

      # ── z.ai coding plan via the Anthropic-compatible gateway ────────────
      # Same endpoint Claude Code uses (essentials.nix → configure-claude),
      # same key file (~/.config/secrets/zai_key — see initExtra above).
      # The [1m] suffix is z.ai's 1M-context variant naming; model IDs are
      # passed through to the gateway verbatim.
      provider.zai-gateway = {
        npm = "@ai-sdk/anthropic";
        name = "Z.ai (coding plan gateway)";
        options = {
          baseURL = "https://api.z.ai/api/anthropic";

          # {env:VAR} is substituted from the process environment at startup
          # (empty string if unset — bash initExtra above exports it). NEVER
          # inline the literal here: this file lands in the world-readable
          # nix store, and zai_key must stay the single source.
          apiKey = "{env:ZAI_API_KEY}";

          # Explicit Bearer on top of the SDK's x-api-key: z.ai documents
          # ANTHROPIC_AUTH_TOKEN (Authorization: Bearer) auth for this
          # endpoint (that's what Claude Code sends).
          headers.authorization = "Bearer {env:ZAI_API_KEY}";
        };

        models = {
          # Haiku-tier slot in the z.ai routing (fast, cheap, 1M ctx) —
          # also the small_model above (summarizer/titles).
          "glm-5.3-flash[1m]" = {
            name = "GLM 5.3 Flash (1M)";
            tool_call = true;
            limit.context = 1000000;
            limit.output = 65536;
          };
          # Sonnet/Opus-tier slot (deep work, 1M ctx). Switch per-session
          # with /models — the default stays the local ollama ladder.
          "glm-5.3[1m]" = {
            name = "GLM 5.3 (1M)";
            tool_call = true;
            limit.context = 1000000;
            limit.output = 65536;
          };
        }; # models
      }; # provider.zai-gateway

    # ── Free-tier MCP servers ──────────────────────────────────────────────
    # (local = opencode spawns the command; first call npx-downloads the
    # package into ~/.npm — a few seconds once, cached after)
    #
    # POSITION MATTERS (fixed 2026-09-15): this block used to sit INSIDE
    # provider.ollama. opencode's schema defines `mcp` only at the TOP level
    # of settings, and provider entries accept no extra keys — so all four
    # servers below were silently never registered. Keep it a sibling of
    # `provider`, never a child.
    mcp = {
      # anti-loop: logic-layer cycle detection. While the 14b-agent model
      # handles token-level repetition, this plugin monitors tool-call
      # patterns to break infinite "ls -> cat -> ls" loops.
      "anti-loop" = {
        type = "local";
        command = [ "${pkgs.nodejs}/bin/npx" "-y" "@opencode/anti-loop-mcp" ];
        enabled = true;
      };

      # context7: current library docs (FastAPI, Tailwind, PyEZ…) injected
      # into prompts — attacks the stale-training-data hallucinations.
      context7 = {
        type = "local";
        command = [ "${pkgs.nodejs}/bin/npx" "-y" "@upstash/context7-mcp" ];
        enabled = true;
      };

      # sequential-thinking: structured plan-then-act scaffold — reported
      # to help small models commit to an action sequence.
      "sequential-thinking" = {
        type = "local";
        command = [ "${pkgs.nodejs}/bin/npx" "-y" "@modelcontextprotocol/server-sequential-thinking" ];
        enabled = true;
      };

      # junos: read-only live lab state from modules/apps/junos-mcp.
      # Resolves via the HM profile PATH.
      junos = {
        type = "local";
        command = [ "junos-mcp" ];
        enabled = true;
      };
    }; # mcp — TOP-LEVEL on purpose; see the note above
    };
  };
}
