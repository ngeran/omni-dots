{ config, pkgs, ... }:

{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    package = pkgs.bluez;
  };

  services.blueman.enable = true;
  hardware.enableRedistributableFirmware = true;

  # NOTE: this previously force-loaded `mt7922` (MediaTek MT7922, WiFi 6E).
  # Wrong twice over: (a) that module name doesn't exist in the kernel, so it
  # errored every boot ("systemd-modules-load: Failed to find module 'mt7922'");
  # and (b) this board's WiFi is a Realtek **RTL8922AE (WiFi 7 / 802.11be)**,
  # driven by rtw89_8922ae — which the kernel auto-loads correctly (wlp10s0,
  # confirmed connected). No force-load is needed or correct; the right driver
  # loads itself. Removed 2026-07-25.

  # Bluetooth on the RTL8922AE combo chip is USB-attached (btusb), which
  # autosuspends by default. Disabling autosuspend keeps the controller awake,
  # dodging the reconnect / re-setup delay some USB BT controllers hit. Harmless
  # on a desktop (minor idle power). Effective after reboot, or immediately:
  #   sudo modprobe -r btusb && sudo modprobe btusb
  boot.extraModprobeConfig = ''
    options btusb enable_autosuspend=N
  '';
}
