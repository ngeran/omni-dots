# =========================================================================
# ghost-drive.nix — suppress the MSI monitor's broken virtual USB storage
# =========================================================================
# The MSI Optix monitor exposes a tiny (~22 KB) virtual USB mass-storage
# device on its USB hub. It is unreadable, so every block probe spams the
# kernel log forever:
#     kernel: I/O error, dev sda, sector 0 op 0x0:(READ)
#     kernel: Buffer I/O error on dev sda, logical block 0, async page read
#
# Device (confirmed via sysfs): idVendor=1462 idProduct=3fa4, product string
# "MSI Gaming Controller"; interface :1.0 = usbhid (the monitor's HID/gaming
# controls), interface :1.1 = usb-storage (the broken 22 KB blob → /dev/sda).
#
# FIX: make usb-storage IGNORE this VID:PID at the kernel level (the `i` =
# IGNORE_DEVICE quirk flag), so the storage interface is never claimed and
# /dev/sda is never created. The usbhid interface (:1.0) is untouched, so the
# monitor's gaming/HID features keep working.
#
# This is the kernel's documented mechanism for "don't let usb-storage bind to
# this device." It replaces fragile approaches (udev `unbind` with hardcoded
# bus paths like 9-2.3:1.1 which shift across reboots, systemd services with
# coreutils /bin/sh which doesn't exist, initrd postDeviceCommands deleting
# /sys/block/sda) — one line, no races, applied before the device is probed.
#
# Set on the kernel command line (NOT boot.extraModprobeConfig) so it applies
# whether usb-storage is built-in or modular, initrd or runtime. uas.quirks is
# belt-and-suspenders in case the device ever claims the uas driver instead.
# =========================================================================
# IMPORTANT: this only kills the sda I/O spam. It does NOT fix the hard freeze
# the machine took — that was an NVIDIA GSP heartbeat timeout → Xid 154 (full
# GPU reset) on the RTX 5080. See modules/nvidiagpu-compute.nix. The ghost
# drive is log noise; the GPU is the stability problem.
# =========================================================================
{ ... }:

{
  boot.kernelParams = [
    "usb-storage.quirks=1462:3fa4:i"   # device binds usb-storage on :1.1 today
    "uas.quirks=1462:3fa4:i"           # defensive: in case it ever claims uas
  ];
}
