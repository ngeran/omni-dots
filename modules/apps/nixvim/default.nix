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

    # Binaries made available to the wrapped nvim's $PATH. lazygit is needed by
    # plugins.lazygit below (the plugin shells out to the `lazygit` binary).
    extraPackages = [ pkgs.lazygit ];

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
      undofile = true; # Persistent undo
      termguicolors = true;
      cursorline = true; # Highlight the current line
      scrolloff = 10;    # Keep 10 lines above/below cursor
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
      which-key.enable = true;
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
      # field at the top" you'd seen). Handles cmdline/messages; snacks.notifier
      # stays responsible for notifications.
      noice = {
        enable = true;
        settings.presets.command_palette = true;
      };
      
      # Modern notifications and UI "snacks" (replaces older notify/noice setups)
      snacks = {
        enable = true;
        settings = {
          bigfile.enable = true;
          notifier.enable = true;
          quickfile.enable = true;
          statuscolumn.enable = true;
          words.enable = true; # Highlights other usage of word under cursor
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
        grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
          python tsx typescript javascript html css json yaml lua nix
          markdown markdown_inline go gomod # Go is essential for Hugo templates
        ];
      };

      # -----------------------------------------------------------------------
      # Navigation & Search
      # -----------------------------------------------------------------------
      # Telescope remains the king of extensibility
      telescope = {
        enable = true;
        keymaps = {
          "<leader>ff" = "find_files";
          "<leader>fg" = "live_grep";
          "<leader>fb" = "buffers";
          "<leader>fh" = "help_tags";
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
      # Python, React, & Web Intelligence (LSP)
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
      # Faster than nvim-cmp, supports snippets and LSP natively
      blink-cmp = {
        enable = true;
        settings = {
          keymap.preset = "default";
          appearance.use_nvim_cmp_as_default = true;
          sources.default = [ "lsp" "path" "snippets" "buffer" ];
        };
      };

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

      # AI: Avante.nvim (Cursor-like experience)
      avante = {
        enable = true;
        settings = {
          provider = "claude"; 
          auto_suggestions_provider = "claude";
        };
      };

      # -----------------------------------------------------------------------
      # Formatting & Linting
      # -----------------------------------------------------------------------
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
            markdown = [ "prettierd" ];
            nix = [ "nixfmt" ];
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
      gitsigns.enable = true;   # Git status in gutter
      lazygit.enable = true;    # Full git TUI inside nvim (<leader>gg); needs pkgs.lazygit (extraPackages)
    };

    # =========================================================================
    # Keymaps
    # =========================================================================
    keymaps = [
      # Git
      { mode = "n"; key = "<leader>gg"; action = "<cmd>LazyGit<CR>"; options = { desc = "Open LazyGit"; }; }

      # File Management: <leader>e is bound in extraConfigLua (Oil sidebar toggle).

      # Trouble (Diagnostics/Errors)
      { mode = "n"; key = "<leader>xx"; action = "<cmd>Trouble diagnostics toggle<CR>"; options = { desc = "Toggle Trouble (Project Errors)"; }; }
      { mode = "n"; key = "<leader>xq"; action = "<cmd>Trouble quickfix toggle<CR>"; options = { desc = "Open Quickfix List"; }; }

      # Productivity & Search
      { mode = "n"; key = "<leader>z"; action = "<cmd>ZenMode<CR>"; options = { desc = "Toggle Zen Mode"; }; }
      { mode = "n"; key = "<leader>td"; action = "<cmd>TodoTelescope<CR>"; options = { desc = "Find Todos"; }; }

      # Tab Navigation (Bufferline)
      { mode = "n"; key = "<Tab>"; action = "<cmd>BufferLineCycleNext<CR>"; options = { desc = "Next Tab"; }; }
      { mode = "n"; key = "<S-Tab>"; action = "<cmd>BufferLineCyclePrev<CR>"; options = { desc = "Previous Tab"; }; }

      # Flash (Jumping)
      { mode = [ "n" "x" "o" ]; key = "s"; action = ''<table.insert(require("flash").jump())>''; options = { desc = "Flash Jump"; }; }

      # Markdown Preview
      { mode = "n"; key = "<leader>mp"; action = "<cmd>MarkdownPreview<CR>"; options = { desc = "Open Markdown Preview"; }; }
      { mode = "n"; key = "<leader>ms"; action = "<cmd>MarkdownPreviewStop<CR>"; options = { desc = "Stop Markdown Preview"; }; }
      { mode = "n"; key = "<leader>mt"; action = "<cmd>MarkdownPreviewToggle<CR>"; options = { desc = "Toggle Markdown Preview"; }; }
    ];

    # =========================================================================
    # Custom Theme Logic (Base16 / Quickshell)
    # =========================================================================
    extraPlugins = [ pkgs.vimPlugins.base16-nvim ];

    extraConfigLua = ''
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
