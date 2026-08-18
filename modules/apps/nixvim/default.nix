{ inputs, pkgs, ... }:

{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # =========================================================================
    # Global Settings
    # =========================================================================
    globals.mapleader = " "; # Sets the Spacebar as your leader key

    # =========================================================================
    # Flake Compatibility & Warning Suppressions
    # =========================================================================
    version.enableNixpkgsReleaseCheck = false;
    nixpkgs.source = inputs.nixpkgs;

    # Binaries made available to the wrapped nvim's $PATH. Plugins like
    # conform (formatting) and lazygit SHELL OUT to these binaries — if they
    # are not here, format-on-save fails SILENTLY (the top bug this config
    # had: prettierd/nixfmt/ruff were never installed, so most filetypes
    # never formatted).
    extraPackages = with pkgs; [
      lazygit        # git TUI (<leader>gg)
      prettierd      # JS/TS/HTML/CSS/JSON/YAML/Markdown formatter (conform)
      nixfmt         # Nix formatter (conform)
      ruff           # Python formatter + the ruff LSP binary
      stylua         # Lua formatter (conform) — for hypr/quickshell lua files
    ];

    # =========================================================================
    # Core Editor Options
    # =========================================================================
    opts = {
      number = true;
      relativenumber = true;
      shiftwidth = 2;
      tabstop = 2;
      expandtab = true;
      smartindent = true;
      ignorecase = true;
      smartcase = true;
      updatetime = 100;
      swapfile = false;
      undofile = true;     # Persistent undo
      termguicolors = true;
      cursorline = true;   # Highlight the current line
      scrolloff = 10;      # Keep 10 lines above/below cursor
      splitbelow = true;   # New horizontal splits go BELOW (LazyVim default)
      splitright = true;   # New vertical splits go RIGHT
      winborder = "rounded"; # Rounded borders on ALL floating windows (0.11+)
    };

    # =========================================================================
    # System & Clipboard Integration
    # =========================================================================
    clipboard = {
      register = "unnamedplus"; # Use system clipboard for all yanks/pastes
      providers.wl-copy.enable = true;
    };

    # =========================================================================
    # Plugins
    # =========================================================================
    plugins = {
      # -----------------------------------------------------------------------
      # UI & Appearance
      # -----------------------------------------------------------------------
      lualine.enable = true;
      web-devicons.enable = true;

      # which-key: shows available keys after pressing <leader>. The `spec`
      # below adds GROUP LABELS so the popup reads like LazyVim's menu
      # ("<leader> f → +find", etc.) instead of an unlabeled key soup.
      which-key = {
        enable = true;
        settings.spec.__raw = ''
          {
            { "<leader>a", group = "ai" },
            { "<leader>b", group = "buffers" },
            { "<leader>c", group = "code" },
            { "<leader>f", group = "find" },
            { "<leader>g", group = "git" },
            { "<leader>h", group = "hunk" },
            { "<leader>m", group = "markdown" },
            { "<leader>s", group = "search" },
            { "<leader>t", group = "todo" },
            { "<leader>x", group = "diagnostics" },
            { "<leader>q", group = "session/quit" },
          }
        '';
      };

      # Bufferline tabline. custom_filter hides the Oil sidebar buffer so the
      # tabline lists only real files (Oil is a navigator, not a "tab").
      bufferline = {
        enable = true;
        settings.options.custom_filter.__raw = ''
          function(buf)
            return vim.bo[buf].filetype ~= "oil"
          end
        '';
      };

      # Replaces the built-in ':' command line with a stylized input — the
      # command_palette preset floats it at the TOP of the screen (the "input
      # field at the top" you'd seen). Handles cmdline/messages; notifications
      # ALSO go through noice — which is why snacks.notifier is DISABLED below
      # (two notification UIs on top of each other = duplicate popups).
      noice = {
        enable = true;
        settings.presets.command_palette = true;
      };

      # Modern notifications and UI "snacks".
      # NOTE: `notifier` is OFF on purpose — noice (above) already renders
      # notifications; enabling both was the double-popup bug.
      # `indent` and `scroll` are the two signature LazyVim looks: scope-aware
      # indent guides and smooth scrolling.
      snacks = {
        enable = true;
        settings = {
          bigfile.enable = true;
          notifier.enable = false;   # noice owns notifications (see above)
          quickfile.enable = true;
          statuscolumn.enable = true;
          words.enable = true;       # Highlights other usage of word under cursor
          indent.enable = true;      # Indent guides, current scope highlighted
          scroll.enable = true;      # Smooth scrolling
        };
      };

      # Shows hex/Tailwind colors in the editor
      colorizer = {
        enable = true;
        settings.user_default_options.names = false; # Don't colorize names like "Blue"
      };

      # -----------------------------------------------------------------------
      # Syntax & Code Structure (Treesitter)
      # -----------------------------------------------------------------------
      treesitter = {
        enable = true;
        settings = {
          indent.enable = true;
          highlight.enable = true;
        };
        # NOTE: Hugo/Go HTML templates ({{ .Site.Title }}) are NOT highlighted
        # by the `go` grammar — that's plain Go source. The TEMPLATE syntax
        # is the `gotmpl` grammar. `bash`/`diff`/`regex` cover justfiles,
        # patches, and common config files.
        grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
          python tsx typescript javascript html css json yaml lua nix
          markdown markdown_inline
          gotmpl                # Hugo / Go templates ({{ ... }} blocks)
          go                    # plain Go source (used by Hugo tooling)
          bash diff regex
        ];
      };

      # Structural text objects + jumps: `af`/`if` select a whole/inner
      # function, `]f`/`[f` jump between functions, `]c`/`[c` between classes
      # — the treesitter-powered motions LazyVim ships.
      treesitter-textobjects = {
        enable = true;
        select = {
          enable = true;
          lookahead = true; # jump to the text object if not on it yet
          keymaps = {
            "af" = "@function.outer";
            "if" = "@function.inner";
            "ac" = "@class.outer";
            "ic" = "@class.inner";
          };
        };
        move = {
          enable = true;
          setJumps = true; # populate the jumplist so C-o/C-i work
          gotoNextStart = {
            "]f" = "@function.outer";
            "]c" = "@class.outer";
          };
          gotoPreviousStart = {
            "[f" = "@function.outer";
            "[c" = "@class.outer";
          };
        };
      };

      # -----------------------------------------------------------------------
      # Navigation & Search
      # -----------------------------------------------------------------------
      # Telescope remains the king of extensibility.
      #  - file_ignore_patterns keeps `find_files` clean in this repo family:
      #    nix build leaves `result*` symlinks everywhere, and direnv's
      #    .direnv/ + node_modules/ are never what you're searching for.
      #  - Keymaps: recent files + git files + symbols (the LazyVim set).
      #  - fzf-native + ui-select extensions are loaded in extraConfigLua
      #    (their plugin packages are in extraPlugins below).
      telescope = {
        enable = true;
        settings.defaults.file_ignore_patterns =
          [ "^result" "%.direnv" "node_modules" "%.git/" ];
        keymaps = {
          "<leader>ff" = "find_files";
          "<leader>fr" = "oldfiles";        # RECENT files
          "<leader>fg" = "live_grep";
          "<leader>gf" = "git_files";       # only git-tracked files
          "<leader>fb" = "buffers";
          "<leader>fh" = "help_tags";
          "<leader>ss" = "lsp_document_symbols";
          "<leader>sS" = "lsp_workspace_symbols";
        };
      };

      # Oil: filesystem editor. Wired as a left sidebar (<leader>e) whose <CR>
      # opens files in the main right window — see extraConfigLua below.
      oil.enable = true;

      # Flash: The fastest way to jump around the screen
      # Press 's' then start typing the word you want to jump to
      flash.enable = true;

      # Trouble: A pretty list for showing errors, warnings, and LSP locations
      trouble.enable = true;

      # -----------------------------------------------------------------------
      # Language Intelligence (LSP)
      # -----------------------------------------------------------------------
      lsp = {
        enable = true;
        servers = {
          # Python: Ruff (Lint/Format) + Basedpyright (Types)
          ruff.enable = true;
          basedpyright.enable = true;

          # Web/React: Vtsls is the modern, faster alternative to tsserver
          vtsls.enable = true;
          tailwindcss.enable = true;
          html.enable = true;
          cssls.enable = true;

          # Content/Hugo: Marksman for Markdown link/ref intelligence
          marksman.enable = true;

          # ── The languages this machine edits DAILY but had no LSP for ──
          nixd.enable = true;   # Nix: hover docs, go-to-definition on options,
                                # inline eval of the config you're reading now
          yamlls.enable = true; # YAML: k3s manifests (labs/, restor8)
          lua_ls = {            # Lua: hypr/*.lua + Quickshell-era lua configs
            enable = true;
            # `hl` is the global the hypr lua config wrapper provides
            # (hl.env, hl.exec_cmd, ...) — tell the LSP it exists.
            settings.diagnostics.globals = [ "vim" "hl" ];
          };
        };
        # LSP Specific Shortcuts
        keymaps.lspBuf = {
          "gd" = "definition";
          "gD" = "references";
          "gt" = "type_definition";
          "gi" = "implementation";
          "K" = "hover";
          "<leader>ca" = "code_action";
          "<leader>rn" = "rename";
        };
      };

      # -----------------------------------------------------------------------
      # Modern Completion (Blink.cmp)
      # -----------------------------------------------------------------------
      # `super-tab` preset: Tab/S-Tab cycle completions and jump snippet
      # placeholders — the behavior most people expect from "modern nvim".
      # `snippets.preset = "luasnip"` wires blink to LuaSnip (enabled below,
      # with the friendly-snippets pack — the for/if/main snippet library
      # that was previously missing entirely).
      blink-cmp = {
        enable = true;
        settings = {
          keymap.preset = "super-tab";
          appearance.use_nvim_cmp_as_default = true;
          snippets.preset = "luasnip";
          sources.default = [ "lsp" "path" "snippets" "buffer" ];
        };
      };

      # Snippet engine + the VSCode-style snippet collection (for/if/main/...)
      luasnip.enable = true;
      friendly-snippets.enable = true;

      # -----------------------------------------------------------------------
      # Markdown & Productivity
      # -----------------------------------------------------------------------
      # MUST HAVE: Renders markdown headers, tables, and boxes in-buffer
      render-markdown.enable = true;

      # Focus mode for writing Hugo posts
      zen-mode.enable = true;

      # Highlight and search for TODO, FIXME, NOTE
      todo-comments.enable = true;

      # Markdown preview in browser
      markdown-preview = {
        enable = true;
        autoLoad = false; # Recommended to keep false for better startup time
      };

      # -----------------------------------------------------------------------
      # AI: Avante.nvim (Cursor-like experience)
      # -----------------------------------------------------------------------
      # The default `claude` provider points at api.anthropic.com with
      # ANTHROPIC_API_KEY — neither exists here. This machine routes Anthropic
      # API traffic through the z.ai gateway using ANTHROPIC_AUTH_TOKEN (set
      # session-wide in modules/apps/essentials.nix), so point avante there.
      avante = {
        enable = true;
        settings = {
          provider = "claude";
          auto_suggestions_provider = "claude";
          claude = {
            endpoint = "https://api.z.ai/api/anthropic";
            api_key_name = "ANTHROPIC_AUTH_TOKEN";
            model = "glm-5.2";   # z.ai model id — bump when you switch models
          };
        };
      };

      # -----------------------------------------------------------------------
      # Session restore (persistence.nvim)
      # -----------------------------------------------------------------------
      # Reopen nvim where you left off: <leader>qs restores the session for
      # the current directory, <leader>ql the LAST session. LazyVim ships
      # exactly this.
      persistence.enable = true;

      # -----------------------------------------------------------------------
      # Formatting & Linting
      # -----------------------------------------------------------------------
      # NOTE: every formatter binary here must exist in extraPackages above —
      # conform shells out to them; missing binary = silent no-op.
      conform-nvim = {
        enable = true;
        settings = {
          formattersByFt = {
            python = [ "ruff_format" ];
            javascript = [ "prettierd" ];
            typescript = [ "prettierd" ];
            javascriptreact = [ "prettierd" ];
            typescriptreact = [ "prettierd" ];
            html = [ "prettierd" ];
            css = [ "prettierd" ];
            json = [ "prettierd" ];
            yaml = [ "prettierd" ];   # k3s manifests
            markdown = [ "prettierd" ];
            nix = [ "nixfmt" ];       # this very repo
            lua = [ "stylua" ];       # hypr/quickshell lua files
          };
          format_on_save = {
            timeout_ms = 500;
            lsp_format_fallback = true;
          };
        };
      };

      # -----------------------------------------------------------------------
      # Editing Quality-of-Life
      # -----------------------------------------------------------------------
      nvim-autopairs.enable = true;
      ts-autotag.enable = true; # JSX/HTML tag renaming
      comment.enable = true;    # Toggle with `gcc`

      # Git status in the gutter + the hunk keymaps that were missing:
      # ]h/[h jump hunks, <leader>hs stage, <leader>hr reset, <leader>hp
      # preview, <leader>hb blame.
      gitsigns = {
        enable = true;
        settings.on_attach.__raw = ''
          function(bufnr)
            local gs = package.loaded.gitsigns
            local function map(mode, l, r, opts)
              opts = opts or {}
              opts.buffer = bufnr
              vim.keymap.set(mode, l, r, opts)
            end
            map("n", "]h", function() gs.next_hunk() end, { desc = "Next hunk" })
            map("n", "[h", function() gs.prev_hunk() end, { desc = "Prev hunk" })
            map("n", "<leader>hs", gs.stage_hunk, { desc = "Stage hunk" })
            map("n", "<leader>hr", gs.reset_hunk, { desc = "Reset hunk" })
            map("n", "<leader>hp", gs.preview_hunk, { desc = "Preview hunk" })
            map("n", "<leader>hb", gs.blame_line, { desc = "Blame line" })
          end
        '';
      };

      lazygit.enable = true;    # Full git TUI inside nvim (<leader>gg); needs pkgs.lazygit (extraPackages)
    };

    # =========================================================================
    # Keymaps
    # =========================================================================
    keymaps = [
      # ── Window management (was entirely missing — LazyVim defaults) ──────
      # C-h/j/k/l move between windows; <leader>-/| split; <leader>wd close.
      { mode = "n"; key = "<C-h>"; action = "<C-w>h"; options = { desc = "Window left"; }; }
      { mode = "n"; key = "<C-j>"; action = "<C-w>j"; options = { desc = "Window down"; }; }
      { mode = "n"; key = "<C-k>"; action = "<C-w>k"; options = { desc = "Window up"; }; }
      { mode = "n"; key = "<C-l>"; action = "<C-w>l"; options = { desc = "Window right"; }; }
      { mode = "n"; key = "<leader>-"; action = "<C-w>s"; options = { desc = "Split below"; }; }
      { mode = "n"; key = "<leader>|"; action = "<C-w>v"; options = { desc = "Split right"; }; }
      { mode = "n"; key = "<leader>wd"; action = "<C-w>c"; options = { desc = "Close window"; }; }

      # ── Buffers (snacks provides the delete functions) ───────────────────
      { mode = "n"; key = "<leader>bd"; action = "<cmd>lua require('snacks').bufdelete()<CR>"; options = { desc = "Delete buffer"; }; }
      { mode = "n"; key = "<leader>bo"; action = "<cmd>lua require('snacks').bufdelete.other()<CR>"; options = { desc = "Delete other buffers"; }; }

      # ── Diagnostics ────────────────────────────────────────────────────────
      # ]d/[d jump between diagnostics (vim.diagnostic.jump is the 0.11+ API;
      # the older goto_next/goto_prev is deprecated).
      { mode = "n"; key = "]d"; action.__raw = ''function() vim.diagnostic.jump({ count = 1, float = true }) end''; options = { desc = "Next diagnostic"; }; }
      { mode = "n"; key = "[d"; action.__raw = ''function() vim.diagnostic.jump({ count = -1, float = true }) end''; options = { desc = "Prev diagnostic"; }; }
      { mode = "n"; key = "gl"; action = "<cmd>lua vim.diagnostic.open_float()<CR>"; options = { desc = "Line diagnostic"; }; }

      # ── Code actions ───────────────────────────────────────────────────────
      { mode = "n"; key = "<leader>cf"; action = "<cmd>lua require('conform').format({ async = true, lsp_fallback = true })<CR>"; options = { desc = "Format file"; }; }
      { mode = "n"; key = "<leader>ch"; action = "<cmd>lua vim.lsp.buf.signature_help()<CR>"; options = { desc = "Signature help"; }; }

      # ── Move lines / selection (Alt+j/k), keeping selection in visual ─────
      { mode = "n"; key = "<A-j>"; action = "<cmd>m .+1<CR>=="; options = { desc = "Move line down"; }; }
      { mode = "n"; key = "<A-k>"; action = "<cmd>m .-2<CR>=="; options = { desc = "Move line up"; }; }
      { mode = "v"; key = "<A-j>"; action = ":m '>+1<CR>gv=gv"; options = { desc = "Move selection down"; }; }
      { mode = "v"; key = "<A-k>"; action = ":m '<-2<CR>gv=gv"; options = { desc = "Move selection up"; }; }

      # ── Todo-comments jumping (the plugin provides the functions) ─────────
      { mode = "n"; key = "]t"; action = "<cmd>lua require('todo-comments').jump_next()<CR>"; options = { desc = "Next todo"; }; }
      { mode = "n"; key = "[t"; action = "<cmd>lua require('todo-comments').jump_prev()<CR>"; options = { desc = "Prev todo"; }; }

      # ── Sessions (persistence.nvim) ───────────────────────────────────────
      { mode = "n"; key = "<leader>qs"; action = "<cmd>lua require('persistence').load()<CR>"; options = { desc = "Restore session"; }; }
      { mode = "n"; key = "<leader>ql"; action = "<cmd>lua require('persistence').load({ last = true })<CR>"; options = { desc = "Restore last session"; }; }
      { mode = "n"; key = "<leader>qd"; action = "<cmd>lua require('persistence').stop()<CR>"; options = { desc = "Don't save session"; }; }

      # ── AI (Avante) ────────────────────────────────────────────────────────
      { mode = "n"; key = "<leader>aa"; action = "<cmd>AvanteAsk<CR>"; options = { desc = "Avante ask"; }; }
      { mode = "n"; key = "<leader>ac"; action = "<cmd>AvanteChat<CR>"; options = { desc = "Avante chat"; }; }
      { mode = "n"; key = "<leader>ae"; action = "<cmd>AvanteEdit<CR>"; options = { desc = "Avante edit"; }; }
      { mode = "n"; key = "<leader>ar"; action = "<cmd>AvanteRefresh<CR>"; options = { desc = "Avante refresh"; }; }

      # ── Git ────────────────────────────────────────────────────────────────
      { mode = "n"; key = "<leader>gg"; action = "<cmd>LazyGit<CR>"; options = { desc = "Open LazyGit"; }; }

      # File Management: <leader>e is bound in extraConfigLua (Oil sidebar toggle).

      # ── Trouble (Diagnostics/Errors) ──────────────────────────────────────
      { mode = "n"; key = "<leader>xx"; action = "<cmd>Trouble diagnostics toggle<CR>"; options = { desc = "Toggle Trouble (Project Errors)"; }; }
      { mode = "n"; key = "<leader>xq"; action = "<cmd>Trouble quickfix toggle<CR>"; options = { desc = "Open Quickfix List"; }; }
      { mode = "n"; key = "<leader>xr"; action = "<cmd>Trouble references toggle<CR>"; options = { desc = "References (Trouble)"; }; }
      { mode = "n"; key = "<leader>cs"; action = "<cmd>Trouble symbols toggle<CR>"; options = { desc = "Symbols (Trouble)"; }; }

      # ── Productivity & Search ──────────────────────────────────────────────
      { mode = "n"; key = "<leader>z"; action = "<cmd>ZenMode<CR>"; options = { desc = "Toggle Zen Mode"; }; }
      { mode = "n"; key = "<leader>td"; action = "<cmd>TodoTelescope<CR>"; options = { desc = "Find Todos"; }; }

      # ── Tab Navigation (Bufferline) ───────────────────────────────────────
      { mode = "n"; key = "<Tab>"; action = "<cmd>BufferLineCycleNext<CR>"; options = { desc = "Next Tab"; }; }
      { mode = "n"; key = "<S-Tab>"; action = "<cmd>BufferLineCyclePrev<CR>"; options = { desc = "Previous Tab"; }; }

      # ── Flash (Jumping) ────────────────────────────────────────────────────
      # Proper Lua keymap (replaces the old <table.insert(...)> hack, which
      # worked by accident and broke dot-repeat).
      { mode = [ "n" "x" "o" ]; key = "s"; action.__raw = ''function() require("flash").jump() end''; options = { desc = "Flash Jump"; }; }

      # ── Markdown Preview ──────────────────────────────────────────────────
      { mode = "n"; key = "<leader>mp"; action = "<cmd>MarkdownPreview<CR>"; options = { desc = "Open Markdown Preview"; }; }
      { mode = "n"; key = "<leader>ms"; action = "<cmd>MarkdownPreviewStop<CR>"; options = { desc = "Stop Markdown Preview"; }; }
      { mode = "n"; key = "<leader>mt"; action = "<cmd>MarkdownPreviewToggle<CR>"; options = { desc = "Toggle Markdown Preview"; }; }
    ];

    # =========================================================================
    # Extra plugins (no dedicated nixvim module needed)
    # =========================================================================
    extraPlugins = with pkgs.vimPlugins; [
      base16-nvim              # palette bridge (see extraConfigLua theme logic)

      # Telescope extensions:
      telescope-fzf-native-nvim # C-accelerated fuzzy sorting (instant, big lists)
      telescope-ui-select-nvim  # ALL vim.ui.select popups (code actions etc.)
                               # get the pretty telescope picker

      # Auto-detect indent style per buffer (tabs/4-space/2-space files stop
      # fighting the global shiftwidth=2; it becomes the fallback default).
      vim-sleuth
    ];

    # =========================================================================
    # Custom Theme Logic (Base16 / Quickshell) + wiring
    # =========================================================================
    extraConfigLua = ''
      -- ── Diagnostic display (the LazyVim look) ──────────────────────────
      -- Small virtual-text prefix, sorted by severity, rounded float on `gl`.
      vim.diagnostic.config({
        virtual_text = { spacing = 4, prefix = "●" },
        underline = true,
        severity_sort = true,
        float = { border = "rounded", source = "if_many" },
      })

      -- ── One-time wiring for plugins enabled above ──────────────────────
      -- LuaSnip: load the VSCode-style snippet pack (friendly-snippets).
      pcall(function() require("luasnip.loaders.from_vscode").lazy_load() end)

      -- Telescope extensions (plugin packages added in extraPlugins).
      -- pcall: if an extension ever fails to build, nvim still starts.
      pcall(function() require("telescope").load_extension("fzf") end)
      pcall(function() require("telescope").load_extension("ui-select") end)

      -- Logic to bridge the Base16 palette to Lualine
      local function lualine_theme(p)
        return {
          normal   = { a = { fg = p.base00, bg = p.base0D, gui = "bold" }, b = { fg = p.base05, bg = p.base01 }, c = { fg = p.base05, bg = p.base02 } },
          insert   = { a = { fg = p.base00, bg = p.base0B, gui = "bold" }, b = { fg = p.base05, bg = p.base01 }, c = { fg = p.base05, bg = p.base02 } },
          visual   = { a = { fg = p.base00, bg = p.base0E, gui = "bold" }, b = { fg = p.base05, bg = p.base01 }, c = { fg = p.base05, bg = p.base02 } },
          replace  = { a = { fg = p.base00, bg = p.base08, gui = "bold" }, b = { fg = p.base05, bg = p.base01 }, c = { fg = p.base05, bg = p.base02 } },
          command  = { a = { fg = p.base00, bg = p.base0A, gui = "bold" }, b = { fg = p.base05, bg = p.base01 }, c = { fg = p.base05, bg = p.base02 } },
          terminal = { a = { fg = p.base00, bg = p.base0C, gui = "bold" }, b = { fg = p.base05, bg = p.base01 }, c = { fg = p.base05, bg = p.base02 } },
          inactive = { a = { fg = p.base03, bg = p.base01 }, b = { fg = p.base03, bg = p.base01 }, c = { fg = p.base03, bg = p.base00 } },
        }
      end

      -- Dynamic theme application based on system-wide Quickshell theme
      local function apply_qs_theme()
        local path = os.getenv("HOME") .. "/.cache/theme/nvim-base16.lua"
        local ok, palette = pcall(dofile, path)
        if ok and type(palette) == "table" and palette.base00 then
          require("base16-colorscheme").setup(palette)

          -- Overrides for visual clarity
          vim.api.nvim_set_hl(0, "Visual",   { bg = "#3a3d4d" })
          vim.api.nvim_set_hl(0, "VisualNC", { bg = "#272a38" })

          pcall(function()
            require("lualine").setup({ options = { theme = lualine_theme(palette) } })
          end)
          return true
        end
        return false
      end

      -- Run on startup
      if not apply_qs_theme() then
        pcall(function() vim.cmd("colorscheme habamax") end)
      end

      -- Refresh theme when returning to Neovim (in case the system theme changed)
      vim.api.nvim_create_autocmd({ "FocusGained", "VimResume" }, {
        callback = apply_qs_theme,
      })

      -- ── Oil sidebar toggle (<leader>e) ────────────────────────────────────
      -- Opens Oil in a 30-column left-hand vertical split (a side panel),
      -- jumps to it if already open, or closes it when invoked from the Oil
      -- window. (Oil has no native sidebar; this approximates one.)
      local function oil_sidebar_toggle()
        if vim.bo.filetype == "oil" then
          vim.cmd("close")
          return
        end
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local ok, ft = pcall(vim.api.nvim_get_option_value, "filetype", { buf = vim.api.nvim_win_get_buf(win) })
          if ok and ft == "oil" then
            vim.api.nvim_set_current_win(win)
            return
          end
        end
        local dir = vim.fn.expand("%:p:h")
        if dir == "" then dir = "." end
        vim.cmd("topleft 30vnew")
        require("oil").open(dir)
      end
      vim.keymap.set("n", "<leader>e", oil_sidebar_toggle, { desc = "Toggle Oil (sidebar)" })

      -- ── Oil sidebar: <CR> opens files on the RIGHT, Oil stays on the left ─
      -- Oil's default <CR> (actions.select) opens the file IN the oil window,
      -- so the sidebar is replaced by the file inside the narrow left split —
      -- the "Oil disappears, file opens on the left" bug. Instead we read the
      -- entry's path, target a non-oil "main" window on the right (creating one
      -- if none exists yet), and :edit the file there. Oil stays put as the
      -- navigator; bufferline lists every opened file as a tab (<Tab>/<S-Tab>).
      -- Directories still navigate in place within the sidebar.
      local function oil_open_in_main()
        local oil = require("oil")
        local entry = oil.get_cursor_entry()
        if not entry then return end
        if entry.type == "directory" then
          oil.select()          -- step into the directory, inside the sidebar
          return
        end
        local dir = oil.get_current_dir() or ""
        local path = dir .. (dir:sub(-1) == "/" and "" or "/") .. entry.name
        local oil_win = vim.api.nvim_get_current_win()
        local target = nil
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          if w ~= oil_win then
            local ok, ft = pcall(vim.api.nvim_get_option_value, "filetype", { buf = vim.api.nvim_win_get_buf(w) })
            if ok and ft ~= "oil" then target = w end
          end
        end
        if not target then      -- first file: create the main window on the right
          vim.cmd("botright vnew")
          target = vim.api.nvim_get_current_win()
        end
        vim.api.nvim_set_current_win(target)
        vim.cmd("edit " .. vim.fn.fnameescape(path))  -- focus lands on the file
      end

      -- Apply the keymap to every oil buffer (covers the toggle, :Oil, etc.).
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "oil",
        callback = function(args)
          vim.keymap.set("n", "<CR>", oil_open_in_main, { buffer = args.buf, desc = "Open in main window (keep Oil)" })
        end,
      })
    '';
  };
}
