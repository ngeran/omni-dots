{
  description = "Omni-Nix: Unified Desktop Architecture";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";
    # --- UNSTABLE ---
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    # --- NVIDIA DRIVER SOURCE PIN (2026-11-08) ---
    # Sole source of the RTX 5080 driver expression in modules/nvidiagpu-compute.nix.
    # 26.05 is frozen at 595.71.05 (recurring Xid 69 Hyprland crashes); this rev
    # carries the same-branch production driver 595.112.07. Pinned to an exact
    # rev — NOT a moving branch — so bumping it moves ONLY the driver.
    # nixpkgs-unstable above is deliberately left on its own (older, vetted)
    # lock: its consumers (matugen/opencode/davinci) must not drift with a
    # driver bump — the Nov-5 unstable broke davinci's zip hash (Blackmagic
    # CDN rotation; see the overlay in modules/apps/video-editing.nix).
    # TODO(26.11): release-26.11 ships ≥ 595.112.07 — delete this input and
    # the overlay in nvidiagpu-compute.nix together.
    nixpkgs-nvidia.url = "github:NixOS/nixpkgs/f9a75f41be3a74eab55d3a7679d34ad6cc0da977";
    # --- DAVINCI RESOLVE SOURCE PIN (2026-11-08) ---
    # Sole source of davinci-resolve in modules/apps/video-editing.nix.
    # The shared nixpkgs-unstable lock above (matugen/opencode/davinci) is
    # older than the Resolve 21.1.1 bump and must not drift just for one app;
    # this exact rev IS the "davinci-resolve: 21.1 -> 21.1.1" commit, and it
    # carries upstream's re-pinned source hash — which is why the local
    # hash-fix overlay was deleted from video-editing.nix. Pinned to an exact
    # rev — NOT a moving branch — so bumping it moves ONLY Resolve.
    nixpkgs-davinci.url = "github:NixOS/nixpkgs/134e02770b7d23bcb1a7dcd763580e5d75a8b4e9";
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

    # -- CLAUDE CODE (AI-powered development assistant) --
    # Claude Code is a terminal-based AI assistant from Anthropic.
    # Provides `claude` command for interactive coding help.
    # Documentation: https://docs.anthropic.com/en/docs/claude-code
    claude-code = {
      url = "github:ryoppippi/nix-claude-code";
      # Use the same nixpkgs version as the rest of the system
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # -- NETWATCH (real-time network diagnostics TUI) --
    # matthart1983/netwatch: Rust+libpcap "htop for your network" — per-process
    # connections, protocol decode (TLS/QUIC/HTTP/DNS), JA4 fingerprinting,
    # C2-beaconing/port-scan detection. Consumed via its UPSTREAM flake (it
    # ships its own buildRustPackage + committed Cargo.lock), pinned to a release
    # tag. NOT in nixpkgs. modules/apps/netwatch.nix cap-wraps the binary with
    # cap_net_raw,cap_bpf,cap_perfmon so the full tool runs without sudo.
    netwatch = {
      url = "github:matthart1983/netwatch/v0.29.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # -- ARTCRAFT (storytold's ArtCraft creative suite: PhotoCraft, VectorCraft,
    # PdfCraft, ...) — upstream's prebuilt release tarballs packaged by
    # olafkfreund's nix-craftapps flake. Consumed by modules/artcraft.nix (the
    # programs.artcraft wrapper: per-app opt-ins + the `artcraft` life-cycle
    # CLI). The input name MUST stay `nix-craftapps` — the helper CLI reads
    # that name from flake.lock.
    nix-craftapps = {
      url = "github:olafkfreund/nix-craftapps";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # -- VELOCITY (the quickshell bar/settings rice) --
    # The live config dir IS its own flake: HM module (tools, fonts, cliphist
    # unit, keybinds single source) + NixOS module (velocity-lock PAM).
    # git+file fetches the repo's TRACKED files — a brand-new file is
    # invisible to omni-apply until it is `git add`-ed (staging alone is
    # enough; no commit needed). Dirty tracked files are picked up as-is.
    velocity.url = "git+file:///home/nikos/.config/quickshell";
  };

  outputs = { self, nixpkgs, home-manager, stylix, nixos-hardware, claude-code, ... }@inputs: {
    # =========================================================================
    # PROJECT TEMPLATES — `nix flake init -t ~/.omni-nix#<name>`
    # =========================================================================
    # Per-stack scaffolds. Each ships a devShell (auto-loaded by direnv,
    # home/devshell.nix) PLUS a Nix-built container image and a `justfile`
    # driving build → push (skopeo) → k3s rollout. See templates/<name>/.
    #
    #   #python / #react / #hugo / #astro — purpose-built per stack (Nix image + deploy)
    #   #dev                      — kitchen-sink devShell only (no image/deploy)
    templates.python = {
      path = ./templates/python;
      description = "Python — FastAPI service or plain script (Nix devShell + image → k3s)";
    };
    templates.hugo = {
      path = ./templates/hugo;
      description = "Hugo static site → nginx image, just → push → k3s rollout";
    };
    templates.react = {
      path = ./templates/react;
      description = "React (Vite) static build → nginx image, just → push → k3s rollout";
    };
    templates.astro = {
      path = ./templates/astro;
      description = "Astro + Tailwind v4 static site → nginx image, just → k3s / Cloudflare Pages";
    };
    templates.dev = {
      path = ./templates/dev;
      description = "Project devShell — node / python / hugo / tailwind (direnv + nix flake)";
    };
    # Bare `nix flake init -t ~/.omni-nix` still gives the kitchen-sink dev shell.
    defaultTemplate = self.templates.dev;

    nixosConfigurations = {
      # --- MAIN DESKTOP RIG ---
      nixos-btw = nixpkgs.lib.nixosSystem {
        # Externally provide `inputs` to all modules. `_module.args.inputs`
        # (below) is resolved through `config`, which recurses infinitely if a
        # module uses `inputs` in its `imports` (e.g. modules/artcraft.nix
        # importing inputs.nix-craftapps.nixosModules.default).
        specialArgs = { inherit inputs; };
        modules = [
          nixos-hardware.nixosModules.common-cpu-amd
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
    };
  };
}
