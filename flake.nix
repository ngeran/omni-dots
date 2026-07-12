{
  description = "Omni-Nix: Unified Desktop Architecture";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";
    # --- HARDWARE ---
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # --- HOME MANAGER ---
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- STYLIX ---
    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # -- NIXVIM --
    nixvim = {
      url = "github:nix-community/nixvim/main"; # Using main for 26.05 compatibility
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # -- MATUGEN (runtime wallpaper → palette) --
    # Pinned to upstream (NOT nixpkgs): nixpkgs matugen 4.0.0's `image`
    # subcommand cannot decode images, so it can't generate palettes. This
    # flake builds a working matugen. It does NOT follow nixpkgs — it vendors
    # its own Rust crate set. Used by Quickshell for INSTANT wallpaper→palette
    # generation at runtime (no rebuild). See modules/matugen.nix for the
    # hybrid contract: Stylix = cold-boot seed, matugen = runtime generator.
    matugen.url = "github:InioX/matugen";
  };

  outputs = { self, nixpkgs, home-manager, stylix, nixos-hardware, nixvim, ... }@inputs: {
    # =========================================================================
    # PROJECT TEMPLATES — `nix flake init -t ~/.omni-nix#<name>`
    # =========================================================================
    # `dev` scaffolds a project devShell (flake.nix + .envrc + .gitignore) for
    # node/python/hugo/tailwind. Auto-loaded by direnv (home/devshell.nix).
    templates.dev = {
      path = ./templates/dev;
      description = "Project devShell — node / python / hugo / tailwind (direnv + nix flake)";
    };

    nixosConfigurations = {
      # --- MAIN DESKTOP RIG ---
      nixos-btw = nixpkgs.lib.nixosSystem {
        modules = [
          nixos-hardware.nixosModules.common-cpu-amd
          nixos-hardware.nixosModules.common-gpu-amd
          nixos-hardware.nixosModules.common-pc-ssd

          ./core                          # Core systems settings
          ./hosts/desktop                 # Desktop hardware & graphic layer

          stylix.nixosModules.stylix      # Wallpaper -> palette generator

          { _module.args.inputs = inputs; }

          home-manager.nixosModules.home-manager {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs; };
              users.nikos = import ./home/default.nix;
              backupFileExtension = "backup";
            };
          }
        ];
      };

      # --- DELL LATITUDE 3440 LAPTOP ---
      dell3440 = nixpkgs.lib.nixosSystem {
        modules = [
          # Swap out the missing dell-latitude attribute for these:
          nixos-hardware.nixosModules.common-cpu-intel
          nixos-hardware.nixosModules.common-pc-ssd

          ./core                          # Inherit the exact same core configuration
          ./hosts/dell3440                # Target folder for your laptop's layout

          stylix.nixosModules.stylix      # Keep the theme engine unified

          { _module.args.inputs = inputs; }

          home-manager.nixosModules.home-manager {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs; };
              users.nikos = import ./home/default.nix;
              backupFileExtension = "backup";
            };
          }
        ];
      };
    };
  };
}
