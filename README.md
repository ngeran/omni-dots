```markdown
# 🪐 Omni-Nix Flake Architecture

Welcome to the unified, declarative NixOS and Home Manager infrastructure configuration framework. This environment is built to balance strict structural reproducibility with an agile, high-performance developer workspace.

Every error has a story—and this configuration is written to ensure reproducibility isn't one of them.

---

## 📂 Directory Structure

The system layout segregates hardware targets, user-space profiles, and modular functional layers for frictionless scalability:

```text
~/.omni-nix/
├── flake.nix                  # Infrastructure entry point, inputs, and channel locks
├── flake.lock                 # Strict cryptographic dependency version pins
├── omni-apply                 # Custom shell wrapper script to rebuild the machine
├── .gitignore                 # Safe-exclusion filters for secret abstraction
├── README.md                  # This architectural reference documentation
│
├── hosts/                     # Machine-specific bare-metal definitions
│   └── desktop/               # Host profile for main system layout
│       ├── default.nix        # System-level imports, networking, and host hooks
│       └── hardware-configuration.nix # Generated kernel modules & file systems
│
├── home/                      # User-space Home Manager state configurations
│   ├── default.nix            # User context, variables, and module mappings
│   ├── apps.nix               # Graphic assets, theme engines, and application lists
│   └── quickshell.nix         # Minimalist UI/UX desktop styling layouts
│
└── modules/                   # Reusable system components and app stacks
    ├── audio.nix              # PipeWire sound infrastructure profiles
    ├── bluetooth.nix          # Hardware radio controller maps
    └── apps/                  # Feature/Stack-specific configurations
        ├── essentials.nix     # Core CLI binaries (eza, bat, git, starship)
        ├── neovim.nix         # Native Neovim runtime wrapper configuration
        ├── programming.nix    # Node, Python, Tailwind, and Font management
        └── virtualization.nix # QEMU, KVM, and libvirtd system hypervisors

```

---

## 🛠️ Operational Guide & Workflows

### 1. How to Add New System-Level Applications/Hardware

If a service requires root privileges, kernel tracking, or kernel drivers (like virtualization hooks or GPU computing):

1. Navigate to `modules/apps/` or create a new file under `modules/`.
2. Wrap your targets inside standard NixOS configuration logic (`environment.systemPackages` or raw `services.x.enable = true;`).
3. Import your module path inside your specific machine file: `hosts/desktop/default.nix`.
4. Stage the file in git (`git add .`) and execute `omni-apply`.

### 2. How to Add User-Level CLI or GUI Applications

If an application is self-contained or configures a user-space profile (like design tools or localized dependencies):

1. Open `home/apps.nix` (or create a dedicated module inside `modules/apps/` that targets `home.packages`).
2. Add the corresponding package name found on [NixOS Package Search](https://search.nixos.org).
3. Stage changes and deploy using `omni-apply`.

### 3. Adding New Devices/Machines

To instantiate a completely new bare-metal target machine (e.g., a laptop or home server) under this Flake footprint:

1. Generate a hardware profile on that machine using `nixos-generate-config --dir ./tmp`.
2. Create a new machine profile folder: `hosts/<machine-name>/`.
3. Copy the generated `hardware-configuration.nix` into that directory, and write a matching `default.nix` mapping its configuration.
4. Declare a corresponding host block matching your hostname inside `flake.nix` under `nixosConfigurations`.

---

## 🛡️ Secrets Management & Best Practices

To safeguard production endpoints and API pathways while utilizing a public GitHub backup repository, follow these core tenets:

* **Never Plaintext Secrets:** Do not hardcode private access tokens, SSH credentials, or API structures inside any tracked `.nix` file.
* **The Out-of-Tree Secret Matrix:** Store raw secret hashes in an untracked local filesystem layer outside the flake tree (e.g., `~/.config/secrets/`).
* **Decoupled Injection Patterns:** Leverage environmental fallback properties inside application modules (e.g., configuring `ANTHROPIC_AUTH_TOKEN_FILE` inside your profile path instead of exposing raw variables to the pure compiler environment).
* **Always Git-Stage:** Nix Flakes evaluate strictly from the current Git index. If you write or modify a `.nix` module, you **must** run `git add <file>` before building, or the compiler will completely ignore it.

---

## 🚀 Cloning to an Entirely New System

To replicate your environment layout on a freshly installed NixOS instance:

### Step 1: Boot on the target machine and capture your hardware state

```bash
sudo nixos-generate-config --show-hardware-config > /tmp/hardware-configuration.nix

```

### Step 2: Clone your configuration repository

```bash
git clone git@github.com:yourusername/omni-nix.git ~/.omni-nix
cd ~/.omni-nix

```

### Step 3: Swap or define your host profile

Replace the template hardware configuration of an existing profile, or establish a brand new machine profile definition using your captured `/tmp/hardware-configuration.nix`. Ensure your system hostname matches the target configuration definition block.

### Step 4: Bootstrapping and Switching Live

Initialize the pipeline manually for the first switch sequence:

```bash
sudo nixos-rebuild switch --flake .#<your-hostname-here>

```

Once the initial generation activates, your custom path wrappers take over. Moving forward, you can modify, extend, and deploy your entire infrastructure ecosystem seamlessly by running your system upgrade utility shortcut:

```bash
omni-apply

```

```

---

### Step 3: Track, Commit, and Backup

Stage these final repository elements:

```bash
cd ~/.omni-nix
git add .gitignore README.md

```

From here, your configuration structure is completely locked down, protected from credential leaks, and fully ready to be pushed to its remote GitHub tracking repository!
