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
    };
  };
}
