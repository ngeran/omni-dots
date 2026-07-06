# 🔄 Omni-Nix Workflow Guide

Complete guide for making changes to your NixOS + Home Manager flake.

---

## 🎯 The Golden Rule

**Nix flakes evaluate from the Git index, NOT the working tree.**

Any new file or unstaged change is **invisible** to `omni-apply`. You must `git add` before rebuilding, or your changes will be ignored.

**Why you see:** `warning: Git tree '/home/nikos/.omni-nix' is dirty`  
**It means:** You have unstaged changes that Nix is ignoring.

**Always do this:**
```bash
git add <changed-files>     # Stage changes FIRST
omni-apply                   # THEN rebuild
git commit -m "message"     # Commit after verification
git push                     # Push to GitHub
```

---

## 📂 Architecture Refresher

```
~/.omni-nix/                        # This repo (github:ngeran/omni-dots)
├── configs/                        # Ingested application configs
│   ├── kitty/                      #   → ~/.config/kitty (symlink)
│   ├── ghostty/                    #   → ~/.config/ghostty (symlink)
│   ├── rofi/                       #   → ~/.config/rofi (symlink)
│   └── ...
├── home/                           # Home Manager config
│   ├── dotfiles.nix               #   Declares xdg.configFile ingestions
│   ├── apps.nix                    #   User packages + GTK theme
│   ├── git.nix                     #   Git identity
│   └── default.nix                 #   Wiring hub (imports modules)
├── modules/                        # System + Home modules
│   ├── apps/                       #   Package collections
│   │   ├── essentials.nix          #   Core CLI tools
│   │   ├── dev-tools.nix           #   Dev tools (nvim, git, etc.)
│   │   └── desktop-apps.nix        #   GUI apps
│   ├── audio.nix                    #   PipeWire + WirePlumber
│   ├── bluetooth.nix               #   Bluetooth
│   └── ...
└── hosts/desktop/                  # Machine-specific hardware + compositor
    └── default.nix                 #   Wiring hub for system modules
```

**Two separate repos:**
- `~/.omni-nix/` → Nix flake (this repo)
- `~/.config/quickshell/` → QML desktop shell (separate repo)

---

## 🔧 Common Workflows

### Workflow 1: Add a New Package (Program)

**Use cases:** Install a CLI tool, GUI app, or system service.

**Step 1: Decide where it belongs**

| Package Type | File to Edit |
|-------------|--------------|
| **User CLI tool** (git, nvim, lazygit) | `modules/apps/essentials.nix` or `modules/apps/dev-tools.nix` |
| **GUI application** (browser, editor) | `modules/apps/desktop-apps.nix` or `home/apps.nix` |
| **System service** (nginx, docker) | Create new `modules/<service>.nix` + import in `hosts/desktop/default.nix` |

**Step 2: Edit the .nix file**

```bash
nvim ~/.omni-nix/modules/apps/essentials.nix
```

Add to the appropriate list:
```nix
home.packages = with pkgs; [
  # Existing packages...
  lazygit        # Add your package here
];
```

**Step 3: Stage and rebuild**

```bash
git -C ~/.omni-nix add modules/apps/essentials.nix
omni-apply
```

**Step 4: Verify and commit**

```bash
# Test that the package works
lazygit --version

# Commit if everything works
git -C ~/.omni-nix commit -m "feat(apps): add lazygit"
git -C ~/.omni-nix push
```

---

### Workflow 2: Edit an Ingested Config

**Use cases:** Change kitty font size, modify rofi theme, update fastfetch config.

**Step 1: Edit under configs/, NOT ~/.config/**

```bash
# ✅ CORRECT: Edit the source file
nvim ~/.omni-nix/configs/kitty/kitty.conf

# ❌ WRONG: Never edit the live symlink (read-only)
nvim ~/.config/kitty/kitty.conf  # This will break or be overwritten
```

**Step 2: Stage and rebuild**

```bash
git -C ~/.omni-nix add configs/kitty/kitty.conf
omni-apply
```

**Step 3: Verify the symlink updated**

```bash
ls -l ~/.config/kitty/kitty.conf
# Should show: -> /nix/store/...
```

**Step 4: Commit and push**

```bash
git -C ~/.omni-nix commit -m "fix(kitty): increase font size to 11"
git -C ~/.omni-nix push
```

---

### Workflow 3: Track a New Config Directory

**Use cases:** You want to version-control `~/.config/new-app`.

**Step 1: Determine the case**

| Case | When? | How |
|------|-------|-----|
| **A: Static (whole-dir)** | App never writes to its config dir | `xdg.configFile."<app>".source = ../configs/<app>;` |
| **B: Runtime writes (per-file)** | App writes to config dir at runtime | Deploy individual files (leave runtime file unmanaged) |
| **C: Separate repo** | Actively developed project | Keep as separate git repo (like quickshell) |

**Step 2A: Copy to configs/ and wire (static config)**

```bash
# 1. Copy the config
cp -r ~/.config/new-app ~/.omni-nix/configs/new-app

# 2. Wire it in dotfiles.nix
nvim ~/.omni-nix/home/dotfiles.nix
```

Add to `xdg.configFile`:
```nix
xdg.configFile = {
  "fastfetch".source  = ../configs/fastfetch;
  "rofi".source       = ../configs/rofi;
  "new-app".source   = ../configs/new-app;  # Add this line
  # ...
};
```

**Step 2B: Per-file deployment (runtime writes)**

If the app writes to its config dir, deploy individual files:

```nix
# In dotfiles.nix, create a list like hyprStaticFiles:
newAppStaticFiles = [
  "config.conf"
  "theme.conf"
  # Exclude runtime-written files like runtime-state.conf
];

# Then deploy per-file:
xdg.configFile = {
  # ... other configs ...
} // builtins.listToAttrs (builtins.map (f: {
  name        = "new-app/${f}";
  value.source = ../configs/new-app/${f};
}) newAppStaticFiles);
```

**Step 3: Stage, rebuild, verify**

```bash
# 3. Stage everything (CRITICAL: new files must be added)
git -C ~/.omni-nix add configs/new-app/ home/dotfiles.nix

# 4. Test build
sudo nixos-rebuild dry-activate --flake ~/.omni-nix#nixos-btw

# 5. Apply
omni-apply

# 6. Verify it's a symlink
ls -l ~/.config/new-app

# 7. Clean backup
rm -rf ~/.config/new-app.backup
```

**Step 4: Commit and push**

```bash
git -C ~/.omni-nix commit -m "feat(dots): ingest new-app config"
git -C ~/.omni-nix push
```

---

### Workflow 4: Add a New System Module

**Use cases:** Create a new system service (e.g., `modules/nginx.nix`).

**Step 1: Create the module**

```bash
nvim ~/.omni-nix/modules/nginx.nix
```

```nix
{ config, pkgs, lib, ... }:
{
  # Your module configuration here
  services.nginx.enable = true;
}
```

**Step 2: Import in the wiring hub**

```bash
nvim ~/.omni-nix/hosts/desktop/default.nix
```

Add to imports:
```nix
imports = [
  ./hardware-configuration.nix
  ../../modules/audio.nix
  ../../modules/bluetooth.nix
  ../../modules/nginx.nix  # Add your module here
  # ...
];
```

**Step 3: Stage and rebuild**

```bash
git -C ~/.omni-nix add modules/nginx.nix hosts/desktop/default.nix
omni-apply
```

---

### Workflow 5: Add a New Home Module

**Use cases:** Create a user-space module (e.g., `modules/home/dev-environment.nix`).

**Step 1: Create the module**

```bash
nvim ~/.omni-nix/modules/home/dev-environment.nix
```

```nix
{ config, pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    nodejs
    python3
  ];
}
```

**Step 2: Import in home/default.nix**

```bash
nvim ~/.omni-nix/home/default.nix
```

Add to imports:
```nix
imports = [
  ./apps.nix
  ./git.nix
  ./dotfiles.nix
  ../../modules/home/dev-environment.nix  # Add your module
  # ...
];
```

**Step 3: Stage and rebuild**

```bash
git -C ~/.omni-nix add modules/home/dev-environment.nix home/default.nix
omni-apply
```

---

### Workflow 6: Change the Wallpaper

**Use cases:** Update desktop wallpaper.

**Step 1: Use the helper script**

```bash
qs-apply-wallpaper /path/to/your/image.jpg
```

This automatically:
1. Copies the image to `~/.omni-nix/wallpaper.jpg`
2. Rebuilds so Stylix regenerates the color palette
3. Seeds the palette to Quickshell

**Step 2: Stage and commit**

```bash
git -C ~/.omni-nix add wallpaper.jpg
git -C ~/.omni-nix commit -m "chore: update wallpaper"
git -C ~/.omni-nix push
```

---

### Workflow 7: Git Identity Changes

**Use cases:** Update git username or email.

**Step 1: Edit the config**

```bash
nvim ~/.omni-nix/home/git.nix
```

```nix
programs.git.settings = {
  user = {
    name = "Your Name";
    email = "your.email@example.com";
  };
  # ...
};
```

**Step 2: Rebuild**

```bash
git -C ~/.omni-nix add home/git.nix
omni-apply
```

**Note:** `git config --global` will fail because HM owns `~/.config/git/config` as a read-only store symlink. Always edit via `home/git.nix` instead.

---

## 🐛 Troubleshooting

### Problem: "my change did nothing"

**Cause:** You forgot to `git add`.

**Solution:**
```bash
git -C ~/.omni-nix status      # Check what's unstaged
git -C ~/.omni-nix add <files> # Stage them
omni-apply                      # Rebuild
```

### Problem: "would be clobbered" error

**Cause:** Home Manager is trying to overwrite a file but a `.backup` already exists.

**Solution:**
```bash
# Remove old backups
rm -rf ~/.config/<app>.backup

# Try again
omni-apply
```

### Problem: Config symlink is broken

**Cause:** You edited `~/.config/<app>` directly (read-only symlink) or the store path was garbage-collected.

**Solution:**
```bash
# Always edit under configs/ and rebuild
nvim ~/.omni-nix/configs/<app>/config.conf
git -C ~/.omni-nix add configs/<app>
omni-apply
```

### Problem: Build fails with "cannot find package"

**Cause:** Package name is wrong or not available in your nixpkgs version.

**Solution:**
```bash
# Search for the correct package name
# Visit: https://search.nixos.org

# Or use nix-search (if installed)
nix-search <package-name>
```

### Problem: "permission denied" on push

**Cause:** SSH key not loaded or wrong permissions.

**Solution:**
```bash
# Check SSH key
ssh-add -l

# Add your key
ssh-add ~/.ssh/id_ed25519

# Try push again
git -C ~/.omni-nix push
```

---

## 📋 Quick Reference

| Task | File to Edit | Commands |
|------|--------------|----------|
| **Add CLI tool** | `modules/apps/essentials.nix` | Edit → `git add` → `omni-apply` |
| **Add GUI app** | `modules/apps/desktop-apps.nix` | Edit → `git add` → `omni-apply` |
| **Edit config** | `configs/<app>/<file>` | Edit → `git add` → `omni-apply` |
| **Track new config** | Copy → `home/dotfiles.nix` | `cp` → Wire → `git add` → `omni-apply` |
| **Add system module** | `modules/<name>.nix` + `hosts/desktop/default.nix` | Create → Import → `git add` → `omni-apply` |
| **Add home module** | `modules/home/<name>.nix` + `home/default.nix` | Create → Import → `git add` → `omni-apply` |
| **Change wallpaper** | Use `qs-apply-wallpaper` | `qs-apply-wallpaper <path>` → `git add` → `omni-apply` |
| **Git identity** | `home/git.nix` | Edit → `git add` → `omni-apply` |

---

## 🚀 The Universal Sequence

For **any** change to this flake:

```bash
# 1. Edit the appropriate file
nvim ~/.omni-nix/<path-to-file>

# 2. Stage changes (CRITICAL)
git -C ~/.omni-nix add <changed-files>

# 3. Dry-run (optional, for big changes)
sudo nixos-rebuild dry-activate --flake ~/.omni-nix#nixos-btw

# 4. Rebuild
omni-apply

# 5. Verify (check that your change works)
<test-your-change>

# 6. Commit and push
git -C ~/.omni-nix commit -m "type(scope): description"
git -C ~/.omni-nix push
```

---

## 📖 Additional Resources

- **README.md** - High-level architecture overview
- **CLAUDE.md** - Guidance for Claude Code AI assistant
- **NixOS Search** - https://search.nixos.org (find packages)
- **Home Manager Options** - https://nix-community.github.io/home-manager/options.html

---

## ⚠️ Important Reminders

1. **NEVER** edit `~/.config/<app>` directly (read-only symlinks)
2. **ALWAYS** `git add` before `omni-apply`
3. **NEVER** commit secrets (use `~/.config/secrets/` + activation scripts)
4. **ALWAYS** remove `.backup` files after verification
5. **NEVER** fold quickshell into this repo (separate repo for a reason)
6. **ALWAYS** test with `dry-activate` for major system changes

---

*Last updated: 2026-07-06*
