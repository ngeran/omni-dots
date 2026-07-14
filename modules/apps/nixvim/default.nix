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
      undofile = true;
      termguicolors = true;
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
      
      # Visualizes colors (Tailwind/CSS) directly in the editor
      nvim-highlight-colors.enable = true; 

      # -----------------------------------------------------------------------
      # Syntax & Code Structure
      # -----------------------------------------------------------------------
      treesitter = {
        enable = true;
        settings = {
          indent.enable = true;
          highlight.enable = true;
        };
        # Ensure specific grammars for your stack are installed
        grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
          python
          tsx
          typescript
          javascript
          html
          css
          json
          yaml
          markdown
          markdown_inline
          go # Hugo is based on Go templates
          lua
          nix
        ];
      };

      # -----------------------------------------------------------------------
      # Search & Fuzzy Finding
      # -----------------------------------------------------------------------
      telescope = {
        enable = true;
        keymaps = {
          "<leader>ff" = "find_files";
          "<leader>fg" = "live_grep";
          "<leader>fb" = "buffers";
        };
      };

      # -----------------------------------------------------------------------
      # Editing Quality-of-Life
      # -----------------------------------------------------------------------
      nvim-autopairs.enable = true;
      # Automatically close and rename HTML/JSX tags (Vital for React)
      ts-autotag.enable = true;
      # Quick commenting (gcc to comment line, gc in visual mode)
      comment.enable = true; 
      # Git signs in the gutter
      gitsigns.enable = true;

      # -----------------------------------------------------------------------
      # Completion & Code Intelligence
      # -----------------------------------------------------------------------
      blink-cmp = {
        enable = true;
        settings.keymap.preset = "default";
      };

      lsp = {
        enable = true;
        servers = {
          # --- Python ---
          basedpyright.enable = true;
          ruff.enable = true;

          # --- React / Web ---
          vtsls.enable = true;      # Better performance than tsserver for TS/JS
          tailwindcss.enable = true; # Tailwind class completion
          html.enable = true;        # General HTML support
          cssls.enable = true;       # CSS/SCSS support

          # --- Hugo / Content ---
          marksman.enable = true;    # Markdown LSP
        };
      };

      conform-nvim = {
        enable = true;
        settings = {
          formattersByFt = {
            python = [ "ruff_format" ];
            # Use prettier for everything else (React, CSS, HTML, JSON)
            javascript = [ "prettierd" ];
            typescript = [ "prettierd" ];
            javascriptreact = [ "prettierd" ];
            typescriptreact = [ "prettierd" ];
            html = [ "prettierd" ];
            css = [ "prettierd" ];
            json = [ "prettierd" ];
            markdown = [ "prettierd" ];
          };
          format_on_save = {
            timeout_ms = 500;
            lsp_format_fallback = true;
          };
        };
      };

      # -----------------------------------------------------------------------
      # File Management & Navigation
      # -----------------------------------------------------------------------
      oil.enable = true;
      neo-tree = {
        enable = true;
        settings.window.width = 30;
      };
    };

    # =========================================================================
    # Keymaps
    # =========================================================================
    keymaps = [
      # Changed Oil to Space + e as requested
      { key = "<leader>e"; action = "<cmd>Oil<CR>"; options = { desc = "Open Oil (edit filesystem as buffer)"; }; }
      # Moved Neo-tree to Space + n (Navigation) to avoid conflict
      { key = "<leader>n"; action = "<cmd>Neotree toggle<CR>"; options = { desc = "Toggle file sidebar (neo-tree)"; }; }
    ];

    # =========================================================================
    # Colorscheme — base16 driven by the live Quickshell theme
    # =========================================================================
    extraPlugins = [ pkgs.vimPlugins.base16-nvim ];

    extraConfigLua = ''
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

      local function apply_qs_theme()
        local path = os.getenv("HOME") .. "/.cache/theme/nvim-base16.lua"
        local ok, palette = pcall(dofile, path)
        if ok and type(palette) == "table" and palette.base00 then
          require("base16-colorscheme").setup(palette)
          vim.api.nvim_set_hl(0, "Visual",   { bg = "#3a3d4d" })
          vim.api.nvim_set_hl(0, "VisualNC", { bg = "#272a38" })
          pcall(function()
            require("lualine").setup({ options = { theme = lualine_theme(palette) } })
          end)
          return true
        end
        return false
      end

      if not apply_qs_theme() then
        pcall(function() vim.cmd("colorscheme habamax") end)
      end

      vim.api.nvim_create_autocmd({ "FocusGained", "VimResume" }, {
        callback = apply_qs_theme,
      })
    '';
  };
}
