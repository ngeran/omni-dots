{ ... }:

# =============================================================================
# Browser-based firmware flashers (Web Serial) — device-node access
# =============================================================================
# Web flashers (Flipper Zero custom firmware, ESP Web Tools / web.esphome.io,
# ZMK, …) talk to USB-serial gadgets through Chromium's Web Serial API, which
# opens /dev/ttyACM* or /dev/ttyUSB* directly as the desktop user.
#
# Those nodes default to root:dialout 0660, so the browser's open() fails with
# EACCES — which flasher UIs routinely misreport as "Serial port busy"
# (observed 2026-08-15 with a Flipper Zero on ttyACM0; ModemManager was ruled
# out, a raw open as nikos returned Permission denied).
#
# Fix: tag the nodes with `uaccess` — systemd-logind grants the currently
# seated user a rw ACL when the device appears, so it takes effect on REPLUG
# with no logout/login (unlike a dialout group add, which only applies to new
# login sessions). nikos is also in `dialout` for CLI tools (esptool,
# stm32flash, minicom…) — see core/default.nix.
#
# Note: Firefox has no Web Serial support at all; these flashers require a
# Chromium-based browser.
# =============================================================================

{
  services.udev.extraRules = ''
    # Grant the active seat user rw access to USB-serial devices (Web Serial
    # flashers). Runs in 00-local.rules, before 73-seat-late.rules applies ACLs.
    SUBSYSTEM=="tty", KERNEL=="ttyACM[0-9]*|ttyUSB[0-9]*", TAG+="uaccess"
  '';
}
