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
    # Suppress version mismatch warning between Nixvim (main/26.11) and NixOS (26.05)
    version.enableNixpkgsReleaseCheck = false;
    
    # Explicitly set nixpkgs source to match your system flake input (silences 'follows' warning)
    nixpkgs.source = inputs.nixpkgs;

    # =========================================================================
    # Core Editor Options
    # =========================================================================
    opts = {
      # Line Numbers
      number = true;         # Show line numbers
      relativenumber = true; # Show relative line numbers for easier jump navigation

      # Indentation & Tab Stops
      shiftwidth = 2;        # Indent by 2 spaces
      tabstop = 2;           # Tab key inserts 2 spaces
      expandtab = true;      # Convert tabs to spaces
      smartindent = true;    # Auto-indent new lines intelligently based on language syntax

      # Search Behavior
      ignorecase = true;     # Case-insensitive search by default
      smartcase = true;      # ...unless an uppercase letter is typed in the search query

      # System Performance & State
      updatetime = 100;      # Faster response time for popups and diagnostics (100ms)
      swapfile = false;      # Disable swap files (prevents unnecessary disk writes)
      undofile = true;       # Maintain persistent undo history across editor restarts
      termguicolors = true;  # Enable 24-bit TrueColor support in the terminal
    };

    # =========================================================================
    # System & Clipboard Integration
    # =========================================================================
    clipboard = {
      register = "unnamedplus";       # Use system clipboard for yank/paste by default
      providers.wl-copy.enable = true; # Use wl-clipboard for Wayland compatibility
    };

    # =========================================================================
    # Plugins
    # =========================================================================
    plugins = {
      # -----------------------------------------------------------------------
      # UI & Appearance
      # -----------------------------------------------------------------------
      lualine.enable = true;      # Clean status line at the bottom
      web-devicons.enable = true; # Filetype icons (requires Nerd Fonts)
      which-key.enable = true;    # Popup panel showing available keybindings
      bufferline.enable = true;   # Top tab bar showing open buffers

      # -----------------------------------------------------------------------
      # Syntax & Code Structure
      # -----------------------------------------------------------------------
      treesitter = {
        enable = true;
        settings = {
          indent.enable = true;    # Treesitter-based auto-indentation
          highlight.enable = true; # Advanced, language-aware syntax highlighting
        };
      };

      # -----------------------------------------------------------------------
      # Search & Fuzzy Finding
      # -----------------------------------------------------------------------
      telescope = {
        enable = true;
        keymaps = {
          "<leader>ff" = "find_files"; # Search for files in the project directory
          "<leader>fg" = "live_grep";  # Search text contents across all files
          "<leader>fb" = "buffers";    # Search through currently open buffers
        };
      };

      # -----------------------------------------------------------------------
      # Editing Quality-of-Life
      # -----------------------------------------------------------------------
      nvim-autopairs.enable = true; # Automatically close brackets, parens, quotes, etc.

      # -----------------------------------------------------------------------
      # Completion & Code Intelligence
      # -----------------------------------------------------------------------
      blink-cmp = {
        enable = true;            # Fast, modern autocompletion (built-in snippet support; auto-wires to LSP)
        settings.keymap.preset = "default";
      };

      lsp = {
        enable = true;
        servers.basedpyright.enable = true; # Type checking, hover, go-to-definition, rename (open-source pyright fork)
        servers.ruff.enable = true;         # Fast linting + formatting + import sorting (replaces flake8/isort)
      };

      conform-nvim = {
        enable = true;            # Format-on-save orchestration (conform.nvim)
        settings = {
          formattersByFt.python = [ "ruff_format" ];  # ruff formatter on Python files
          format_on_save = {
            timeout_ms = 500;
            lsp_format_fallback = true; # fall back to LSP (ruff) formatting if no conform formatter
          };
        };
      };

      # -----------------------------------------------------------------------
      # File Management & Navigation
      # -----------------------------------------------------------------------
      oil.enable = true;      # Edit the filesystem like a buffer — rename/move/create by editing text, then :w to apply (stevearc/oil.nvim)
      neo-tree = {
        enable = true;        # Persistent sidebar file tree for navigation (VS Code-style)
        settings.window.width = 30;
      };
    };

    # =========================================================================
    # Keymaps
    # =========================================================================
    keymaps = [
      { key = "<leader>e"; action = "<cmd>Neotree toggle<CR>"; options = { desc = "Toggle file sidebar (neo-tree)"; }; }
      { key = "<leader>E"; action = "<cmd>Oil<CR>"; options = { desc = "Open Oil (edit filesystem as buffer)"; }; }
    ];

    # =========================================================================
    # Colorscheme — base16 driven by the live Quickshell theme
    # =========================================================================
    # nvim-base16 (RRethy/base16-nvim) applies a base16 palette to nvim's
    # highlight groups. Quickshell's ThemeService writes
    # ~/.cache/theme/nvim-base16.lua on every theme change (see
    # settings/services/ThemeService.qml syncToExternalApps). We dofile() it
    # and pass to setup(); pcall + fallback ensure nvim still starts cleanly if
    # the file doesn't exist yet (e.g. before the first theme switch).
    extraPlugins = [ pkgs.vimPlugins.base16-nvim ];

    extraConfigLua = ''
      -- lualine theme derived from the base16 palette. lualine's 'auto' theme
      -- can't detect base16 (it doesn't set g.colors_name), so we build a theme
      -- table from the same palette. Each mode's 'a' block is the mode badge
      -- (dark fg on a palette accent), 'b'/'c' are status sections.
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
          -- setup() applies the colorscheme directly (sets all base16 highlight
          -- groups) — no separate :colorscheme call needed (RRethy/base16-nvim
          -- doesn't register a named scheme; calling :colorscheme base16 errors).
          require("base16-colorscheme").setup(palette)

          -- Text-selection visibility: base16 derives the Visual group from
          -- base02, but this theme clamps base00/base01/base02 all to pure
          -- black (#000000, oledClamp) for the OLED look — so the selection
          -- background is identical to the editor background and renders
          -- completely invisible. Override it with a clearly-visible,
          -- OLED-friendly mid blue-gray (kept above the near-black band QD-OLED
          -- renders noisily) that harmonises with the blue-gray text palette.
          -- Re-applied on every theme reload so it survives live theme switches.
          vim.api.nvim_set_hl(0, "Visual",   { bg = "#3a3d4d" })
          vim.api.nvim_set_hl(0, "VisualNC", { bg = "#272a38" })
          -- lualine: re-theme from the same palette so the statusline matches.
          -- pcall in case lualine isn't loaded (e.g. lazy-loaded / absent).
          pcall(function()
            require("lualine").setup({ options = { theme = lualine_theme(palette) } })
          end)
          return true
        end
        return false
      end
      -- Apply on startup; fall back to a bundled scheme if the file is absent.
      if not apply_qs_theme() then
        pcall(function() vim.cmd("colorscheme habamax") end)
      end
      -- Live reload: re-apply when nvim regains focus (theme may have changed).
      vim.api.nvim_create_autocmd({ "FocusGained", "VimResume" }, {
        callback = apply_qs_theme,
      })
    '';
  };
}
