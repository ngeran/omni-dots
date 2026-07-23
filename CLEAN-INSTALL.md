# Clean Install — NixOS on the ASUS X870E-PLUS TUF

Step-by-step: wipe + reinstall NixOS on the new **ASUS X870E-PLUS TUF**
(AMD AM5 / X870E chipset) and restore the full `omni-nix` flake desktop —
Hyprland + Quickshell bar/settings + the Claude/z.ai gateway.

> This doc is committed to the repo, so it's on GitHub (`ngeran/omni-dots`) and
> readable from your phone / the live ISO / another machine **after** you wipe.
> Open it there while you install.

---

## Hardware context — what carries over, what changes

| Part | Old board | X870E-PLUS TUF | Flake impact |
|---|---|---|---|
| **CPU** | AMD Ryzen 7 7700X (AM5) | still AM5 (7700X drops in, or newer AM5) | **none** — `nixos-hardware common-cpu-amd` still correct |
| **GPU** | NVIDIA RTX 5080 | unchanged | **none** — `modules/nvidiagpu-compute.nix` still correct |
| **Storage** | (your drives) | same drives / new layout | **regenerate `hardware-configuration.nix`** (new UUIDs) |
| **Wifi/BT** | MediaTek MT7922 (force-loaded) | Wi-Fi 7 (likely MediaTek MT7925) | **verify after boot** — may need to update `modules/bluetooth.nix` (mt7922 → new module) |
| **Ethernet** | — | Realtek 2.5GbE (RTL8125) | works out of the box |

**Bottom line:** no CPU/GPU module edits needed. Just regenerate the hardware
config, and check wifi after first boot.

---

## §1 — BACK UP FIRST (before wiping). These are NOT in git.

Do this on the **current** system before you wipe anything. The two repos are on
GitHub (restorable), but these are **gitignored / personal** and will be **gone**
after the wipe:

| Back up | From | Why |
|---|---|---|
| **Secrets** | `~/.config/secrets/` → `zai_key`, `zai_usage_key` | The Claude/z.ai gateway + ZAI usage service read these. **Copy to a USB stick / password manager.** Without them the gateway won't authenticate. |
| **SSH keys** | `~/.ssh/` (private key `id_*`, `config`, `known_hosts`) | Needed to `git clone` your **private** repos on the new box. (Or `ssh-keygen` a new key + add the pubkey to GitHub.) |
| **The two repo dirs** (optional but easiest) | `~/.omni-nix/` and `~/.config/quickshell/` | Copy to USB too → lets you restore **without** network during install. GitHub stays as the fallback. |
| Personal/untracked | `~/` project work, `~/.config/chromium`, shell history, GPG keys | Your call. (Mind the old `~/.config/chromium` leak — never commit browser profiles.) |

**Right before wiping, push both repos** so GitHub has the current state:
```bash
git -C ~/.omni-nix push        # ngeran/omni-dots
git -C ~/.config/quickshell push   # ngeran/velocity
git -C ~/.omni-nix status      # confirm clean
git -C ~/.config/quickshell status
```

## §2 — Know which drive you're wiping

The flake mounts `/mnt/DATA-2T` (ext4) + `/mnt/SSD-250` (ntfs) — if those are
**separate physical drives** from the OS drive, they survive an OS-wipe untouched.
Confirm the OS drive + `/persist` location:
```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT
mount | grep -E '/persist|/mnt/'
```
Note the OS drive (e.g. `/dev/nvme0n1`) — that's the one you'll wipe.

---

## §3 — Boot the NixOS ISO on the X870E

1. Flash a NixOS ISO to a USB (**graphical** GNOME/KDE ISO = easiest, has a
   NetworkManager applet for wifi; **minimal** ISO is fine if you have Ethernet —
   the X870E's 2.5GbE port works out of the box).
2. BIOS on the X870E: **disable Secure Boot** (for the ISO), confirm **UEFI** mode.
3. Boot the USB. Get network up (Ethernet cable, or wifi via the desktop applet).

## §4 — Partition + mount the OS drive

Single-drive EFI layout (adjust `nvme0n1` to your drive; add encryption/mirrors
as needed):
```bash
lsblk                                                       # confirm the OS device, e.g. /dev/nvme0n1
sudo parted /dev/nvme0n1 -- mklabel gpt
sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB
sudo parted /dev/nvme0n1 -- set 1 esp on
sudo parted /dev/nvme0n1 -- mkpart primary 1GiB 100%
sudo mkfs.fat -F32 -n ESP /dev/nvme0n1p1
sudo mkfs.ext4 -L nixos   /dev/nvme0n1p2
sudo mount /dev/nvme0n1p2 /mnt
sudo mkdir -p /mnt/boot && sudo mount /dev/nvme0n1p1 /mnt/boot
```

## §5 — Generate hardware config + get the flake + install

```bash
sudo nixos-generate-config --root /mnt     # → /mnt/etc/nixos/hardware-configuration.nfig (NEW board's UUIDs/filesystems)
```

Get the flake into its final location and **swap in the new hardware config**
(the committed `hosts/desktop/hardware-configuration.nix` is for the *old* board
— reusing it = won't mount/boot). Restore from your USB backup, or clone:

```bash
# Option A — restore from USB backup (no network needed):
sudo cp -r /run/media/usb/omni-nix  /mnt/home/nikos/.omni-nix
# Option B — clone from GitHub (needs the SSH key on the ISO, or HTTPS + a PAT):
sudo mkdir -p /mnt/home/nikos
sudo git clone git@github.com:ngeran/omni-dots.git /mnt/home/nikos/.omni-nix

# overwrite the committed hardware-configuration.nix with the new board's:
sudo cp /mnt/etc/nixos/hardware-configuration.nix \
        /mnt/home/nikos/.omni-nix/hosts/desktop/hardware-configuration.nix
```

Install (builds the **whole** system — long, ~30–90 min depending on bandwidth):
```bash
sudo nixos-install --root /mnt --flake /mnt/home/nikos/.omni-nix#nixos-btw
# set root + nikos passwords when prompted
sudo reboot
```
(If you changed CPU/GPU (you didn't here), edit `flake.nix`'s `nixosConfigurations.nixos-btw`
imports before `nixos-install` — e.g. `common-cpu-amd`→`common-cpu-intel`. Not needed for AM5→AM5.)

## §6 — First boot: restore + apply + verify

Log in as `nikos`. Then:

```bash
# 1. Restore secrets (the activation script reads these to write ~/.claude/settings.json):
mkdir -p ~/.config/secrets
cp /run/media/usb/{zai_key,zai_usage_key} ~/.config/secrets/
chmod 600 ~/.config/secrets/*

# 2. Restore SSH keys (or ssh-keygen + add new pubkey to GitHub):
cp -r /run/media/usb/.ssh ~/.ssh && chmod 700 ~/.ssh && chmod 600 ~/.ssh/*

# 3. Restore the Quickshell desktop shell:
git clone git@github.com:ngeran/velocity.git ~/.config/quickshell

# 4. First full build on the new box (long):
omni-apply   # = sudo nixos-rebuild switch --flake ~/.omni-nix/#nixos-btw
```

Then verify (re-login if needed for the desktop to come up):
- **Desktop:** Hyprland + Quickshell bar/settings render.
- **Claude gateway:** `cat ~/.claude/settings.json` shows the token (written by the
  `configure-claude` activation script from `~/.config/secrets/zai_key`). If empty,
  confirm the secret is present + `omni-apply` again.
- **Theme:** `~/.cache/theme/colors.json` reseeded by activation; bar shows the theme.
- **Data mounts:** `ls /mnt/DATA-2T /mnt/SSD-250` (auto-mounted per the flake — only
  if those drives are connected).
- **`/persist`:** the flake bind-mounts nvim state onto `/persist` and k3s/docker use
  `/persist/var/lib/...`. If a boot stalls on a `/persist` mount, `sudo mkdir -p`
  the target dir (see `hosts/desktop/default.nix`) + `omni-apply`.

**Wifi on the X870E (verify):** if you use the board's Wi-Fi 7 (not the old MT7922
card) and it's not detected, check `ip link` + `lspci -nnk | grep -iA3 net`. The
flake force-loads `mt7922` in `modules/bluetooth.nix`; the new chipset (likely
MediaTek **MT7925**) needs `mt7925` instead. Edit that module + `omni-apply`.
(Ethernet works regardless, so this never blocks the install.)

## §7 — Done checklist

- [ ] Backed up **secrets** + **SSH keys** + (optional) the two repo dirs **before** wiping
- [ ] Pushed both repos before wiping
- [ ] Wiped only the **OS** drive (data drives left intact)
- [ ] **Regenerated** `hardware-configuration.nix` for the new board (didn't reuse the committed one)
- [ ] `nixos-install --flake …#nixos-btw` succeeded
- [ ] Restored secrets + SSH + velocity
- [ ] `omni-apply` succeeded; desktop + Quickshell up
- [ ] Claude gateway works; data mounts present; `/persist` OK

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Boot fails / can't mount root | `hardware-configuration.nix` UUIDs/filesystems are wrong — re-check §5 (regenerate, don't reuse the old one). |
| Blank display after boot | RTX 5080 needs the NVIDIA driver (`modules/nvidiagpu-compute.nix`). Boot the ISO, re-check `nixos-install` built it; the `nvidia` driver must be in the toplevel. |
| `omni-apply`: "would be clobbered" / `.backup` files | the flake's `backupFileExtension = "backup"` moves conflicting live files aside; if still stuck, move the live file out of the way and re-run. |
| `/persist` mount fails at boot | `sudo mkdir -p /persist/<subdir>` for each bind target in `hosts/desktop/default.nix`, then `omni-apply`. |
| Wifi (MT7925) not detected | update the wifi module in `modules/bluetooth.nix` (mt7922 → mt7925), `omni-apply`. Ethernet works meanwhile. |
| Can't clone private repos on the ISO | restore the repo dirs from the USB backup (§5 Option A), or copy the SSH key onto the ISO, or clone over HTTPS with a GitHub PAT. |
