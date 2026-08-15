{ pkgs, ... }:

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
# with no logout/login (unlike the dialout group add in core/default.nix,
# which only reaches processes started after the next login).
#
# WHY services.udev.packages AND NOT extraRules: extraRules lands in
# /etc/udev/rules.d/99-local.rules, which sorts AFTER systemd's
# 73-seat-late.rules — the rule that converts the uaccess tag into an ACL.
# Tagged too late = no ACL is ever applied (first attempt failed exactly like
# that). Shipping the rule as a package with a 70- filename makes it sort
# before 73-seat-late.rules, so the ACL lands at enumeration time.
#
# Note: Firefox has no Web Serial support at all; these flashers require a
# Chromium-based browser.
# =============================================================================

{
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "serial-uaccess-udev-rules";
      destination = "/lib/udev/rules.d/70-serial-uaccess.rules";
      text = ''
        # Grant the active seat user rw access to USB-serial devices
        # (browser firmware flashers via Web Serial). Must run before
        # 73-seat-late.rules applies the ACL — hence the 70- filename.
        SUBSYSTEM=="tty", KERNEL=="ttyACM[0-9]*|ttyUSB[0-9]*", TAG+="uaccess"
      '';
    })
  ];
}
