# modules/apps/opencode.nix
# OpenCode — open-source AI coding agent for the terminal (opencode.ai).
# Default model = the z.ai coding plan (glm-5.3) via its Anthropic-compatible
# gateway, authenticated from ~/.config/secrets/zai_key — the ONE location
# every Z.ai key reference points at (Claude Code's configure-claude activation
# script in modules/apps/essentials.nix reads the same file). The LOCAL Ollama
# ladder (modules/ollama.nix, qwen2.5:14b variants on the 5080) stays declared
# for offline / private sessions; switch to it with /models.
#
# The agent pipeline (plan -> build -> explore/reviewer), prompt, skill and
# command files live under configs/opencode/ and are deployed next to this
# config. This module is Home-Manager level (user CLI), mirroring claude.nix.
#
# Global plugins: TokenEconomizer (microsoft/TokenEconomizer) is loaded from a
# clone under ~/github/ai-plugins, not vendored here — see the link at the end.
{ inputs, config, pkgs, lib, ... }:

let
  isSupported = pkgs.stdenv.hostPlatform.system == "x86_64-linux";

  # Clones of AI/agent GitHub repos live OUTSIDE this flake (the user's
  # convention), so they can be updated with `git pull` without a rebuild.
  aiPluginsDir = "${config.home.homeDirectory}/github/ai-plugins";

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

      # Default agent model: the strong cloud tier. Local Ollama remains
      # selectable per-session via /models (see provider.ollama below) for
      # offline work; its 14B variants are deliberately not the default —
      # the cloud gateway is dramatically faster and has a 1M context.
      model = "zai-gateway/glm-5.3";

      # Background housekeeping (titles, anchored session summaries) goes to
      # the fast/cheap sibling. opencode runs a summarizer subagent after
      # every turn; using the strong model there would burn tokens for no
      # benefit.
      small_model = "zai-gateway/glm-5.3-flash";

      # Dynamic context pruning (DCP): replaces stale tool output with
      # summaries so long sessions stay cheap. Pinned — the binary version is
      # owned by this flake, so don't let the plugin float on @latest.
      plugin = [ "@tarquinen/opencode-dcp@3.2.0" ];

      # opencode's own coarse compaction. `prune` is deprecated; DCP handles
      # the fine-grained pruning. `auto` keeps the safety net for very long
      # sessions.
      compaction.auto = true;

      # Cap tool output so one huge log/build dump cannot eat the context
      # window. Full output is still written to disk by opencode.
      tool_output = {
        max_lines = 600;
        max_bytes = 32768;
      };

      # ── Permissions ──────────────────────────────────────────────────────
      # Broad rules first, narrow rules last: opencode's LAST matching rule
      # wins, and builtins.toJSON sorts keys alphabetically — "*" sorts first,
      # so the catch-all must stay the broad rule above the specific ones.
      permission = {
        edit = "ask";
        webfetch = "ask";
        websearch = "ask";

        # MCP tool schemas are only sent when the tools are enabled, so
        # Context7 is off everywhere except the plan/build agents below.
        "context7_*" = "deny";

        bash = {
          "*" = "ask";
          "git status*" = "allow";
          "git diff*" = "allow";
          "git log*" = "allow";
          "git show*" = "allow";
          "ls*" = "allow";
          "rg *" = "allow";
          "just check*" = "allow";
          "just test*" = "allow";
          "nix flake check*" = "allow";
          "nixos-rebuild dry-build*" = "allow";
          "nixos-rebuild switch*" = "deny";
          "git push*" = "ask";
          "rm *" = "ask";
        };
      };

      # ── Agent pipeline: plan -> build -> review ──────────────────────────
      # plan writes ONLY PLAN.md; build executes it; explore/reviewer are
      # read-only subagents in their own contexts, so 40-file searches cost
      # the main context a paragraph instead of the whole tree.
      agent = {
        plan = {
          model = "zai-gateway/glm-5.3";
          description = "Read-only planner: explores, then writes PLAN.md only.";
          prompt = "{file:./prompts/plan.txt}";
          steps = 24;
          permission = {
            edit = {
              "*" = "deny";
              "PLAN.md" = "allow";
              "**/PLAN.md" = "allow";
            };
            bash = {
              "*" = "deny";
              "git status*" = "allow";
              "git diff*" = "allow";
              "git log*" = "allow";
              "git show*" = "allow";
              "rg *" = "allow";
              "ls*" = "allow";
            };
            webfetch = "allow";
            "context7_*" = "allow";
          };
        };

        build = {
          model = "zai-gateway/glm-5.3";
          description = "Builder: executes PLAN.md in small, verified steps.";
          prompt = "{file:./prompts/build.txt}";
          permission = {
            "context7_*" = "allow";
          };
        };

        explore = {
          model = "zai-gateway/glm-5.3-flash";
          steps = 16;
        };
      };

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
      #
      # TWO wire-format traps, both verified by capturing opencode's actual
      # outbound request (local echo server + curl replays, 2026-11-04):
      #
      # 1. baseURL MUST include "/v1". Claude Code appends "/v1/messages"
      #    to ANTHROPIC_BASE_URL itself, but the @ai-sdk/anthropic package
      #    opencode bundles (provider-utils 4.x) defaults to
      #    "https://api.anthropic.com/v1" and appends ONLY "/messages".
      #    Without the /v1 here, opencode hits .../api/anthropic/messages,
      #    the gateway answers {"code":500,"msg":"404 NOT_FOUND"} with no
      #    SSE events → the AI SDK sees an EMPTY stream (step-finish
      #    reason="unknown", 0 tokens) → opencode's agent loop steps
      #    forever with zero errors (observed: 462+ silent steps ≈
      #    "select Z.ai and nothing happens"). opencode 1.15.10 appended
      #    /v1 itself; 1.18.x's newer SDK silently changed the convention.
      #
      # 2. MODEL IDs MUST NOT carry the "[1m]" suffix (was
      #    glm-5.3-flash[1m] / glm-5.3[1m]). "[1m]" is a Claude Code-side
      #    convention — CC strips it and sends `anthropic-beta: context-1m`
      #    on the wire. opencode passes the ID verbatim and the gateway
      #    1211-rejects it ("Unknown Model"). Plain IDs + the beta header
      #    below reproduce exactly what Claude Code sends.
      provider.zai-gateway = {
        npm = "@ai-sdk/anthropic";
        name = "Z.ai (coding plan gateway)";
        options = {
          baseURL = "https://api.z.ai/api/anthropic/v1";

          # {env:VAR} is substituted from the process environment at startup
          # (empty string if unset — bash initExtra above exports it). NEVER
          # inline the literal here: this file lands in the world-readable
          # nix store, and zai_key must stay the single source.
          apiKey = "{env:ZAI_API_KEY}";

          # Explicit Bearer on top of the SDK's x-api-key: z.ai documents
          # ANTHROPIC_AUTH_TOKEN (Authorization: Bearer) auth for this
          # endpoint (that's what Claude Code sends). The anthropic-beta
          # header is the 1M-context opt-in — the wire equivalent of CC's
          # "[1m]" suffix (see the model-ID note above).
          headers = {
            authorization = "Bearer {env:ZAI_API_KEY}";
            anthropic-beta = "context-1m-2025-08-07";
          };
        };

        models = {
          # Haiku-tier slot in the z.ai routing (fast, cheap) — also the
          # small_model above (summarizer/titles).
          "glm-5.3-flash" = {
            name = "GLM 5.3 Flash";
            tool_call = true;
            limit.context = 1000000;
            limit.output = 65536;
          };
          # Sonnet/Opus-tier slot (deep work). Switch per-session with
          # /models — the default stays the local ollama ladder.
          "glm-5.3" = {
            name = "GLM 5.3";
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

    # ── Agent pipeline files ───────────────────────────────────────────────
    # Deployed PER-FILE (not as a whole-dir source) so ~/.config/opencode
    # stays a real, writable directory — opencode writes auth/state and some
    # runtime files next to the config. Sources live in configs/opencode/.
    #
    # Prompt paths in opencode.json are relative to the config file, hence
    # ./prompts/plan.txt -> ~/.config/opencode/prompts/plan.txt.
    xdg.configFile."opencode/AGENTS.md".source =
      ../../configs/opencode/AGENTS.md;
    xdg.configFile."opencode/prompts/plan.txt".source =
      ../../configs/opencode/prompts/plan.txt;
    xdg.configFile."opencode/prompts/build.txt".source =
      ../../configs/opencode/prompts/build.txt;
    xdg.configFile."opencode/agents/reviewer.md".source =
      ../../configs/opencode/agents/reviewer.md;
    xdg.configFile."opencode/commands/plan.md".source =
      ../../configs/opencode/commands/plan.md;
    xdg.configFile."opencode/commands/ship.md".source =
      ../../configs/opencode/commands/ship.md;
    xdg.configFile."opencode/skills/nixos/SKILL.md".source =
      ../../configs/opencode/skills/nixos/SKILL.md;
    xdg.configFile."opencode/skills/astro/SKILL.md".source =
      ../../configs/opencode/skills/astro/SKILL.md;
    xdg.configFile."opencode/skills/quickshell/SKILL.md".source =
      ../../configs/opencode/skills/quickshell/SKILL.md;
    xdg.configFile."opencode/skills/python/SKILL.md".source =
      ../../configs/opencode/skills/python/SKILL.md;

    # ── Global plugin: TokenEconomizer ─────────────────────────────────────
    # Microsoft Research's cost-control plugin (micro-skills / loop guard).
    # opencode loads every file in ~/.config/opencode/plugins/ globally, so a
    # link here applies to every project, not just this flake.
    #
    # mkOutOfStoreSymlink is REQUIRED, not a style choice: the plugin resolves
    # scripts/ and lib/ relative to its own real path (import.meta.url →
    # plugin/opencode/..), so a copy into the nix store would break it. The
    # out-of-store link also means `git pull` in the clone updates the running
    # plugin with no rebuild. Dangling if the clone is missing — re-clone with:
    #   git clone https://github.com/microsoft/TokenEconomizer.git \
    #     ~/github/ai-plugins/TokenEconomizer
    xdg.configFile."opencode/plugins/tokeneconomizer.ts".source =
      config.lib.file.mkOutOfStoreSymlink
        "${aiPluginsDir}/TokenEconomizer/plugin/opencode/tokeneconomizer.ts";
  };
}
