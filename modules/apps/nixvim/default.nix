{ inputs, pkgs, ... }:

{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # =========================================================================
    # Flake Compatibility & Warning Suppressions
    # =========================================================================
    version.enableNixpkgsReleaseCheck = false;
    nixpkgs.source = inputs.nixpkgs;

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
      register = "unnamedplus";
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
      bufferline.enable = true;
      
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

      # Oil: Edit your file system like a normal buffer
      oil.enable = true;
      
      # Neo-tree: Sidebar for project visualization
      neo-tree = {
        enable = true;
        settings.window.width = 30;
      };

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

      # AI: Avante.nvim (Cursor-like experience)
      # Note: Requires an API key (Claude/OpenAI) in your env
      avante = {
        enable = true;
        settings = {
          provider = "claude"; # Recommended for coding
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
    };

    # =========================================================================
    # Keymaps
    # =========================================================================
    keymaps = [
      # File Management
      { key = "<leader>e"; action = "<cmd>Oil<CR>"; options = { desc = "Open Oil (File System)"; }; }
      { key = "<leader>n"; action = "<cmd>Neotree toggle<CR>"; options = { desc = "Toggle Sidebar"; }; }
      
      # Productivity
      { key = "<leader>z"; action = "<cmd>ZenMode<CR>"; options = { desc = "Toggle Zen Mode"; }; }
      { key = "<leader>td"; action = "<cmd>TodoTelescope<CR>"; options = { desc = "Find Todos"; }; }
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
    '';
  };
}
