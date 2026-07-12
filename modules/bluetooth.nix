{ config, pkgs, ... }:

{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    package = pkgs.bluez;
  };

  services.blueman.enable = true;
  hardware.enableRedistributableFirmware = true;

  # Force-load driver for typical ASUS/MediaTek Wi-Fi+BT modules (MT7922/MT7921)
  boot.kernelModules = [ "mt7922" ];

  # MT7921/MT7922 Bluetooth travels over btusb, which autosuspends by default.
  # When a device reconnects the controller often fails to wake cleanly — kernel
  # logs "command tx timeout / failed to reset (-19)" and the controller takes
  # ~20s to re-setup before a mouse/keyboard reconnects (sometimes needing a
  # reboot). Disabling btusb autosuspend keeps the controller awake. This matches
  # what was observed: btusb enable_autosuspend=Y + a 20s hci0 re-setup storm.
  # Takes effect after reboot (or: sudo modprobe -r btusb && sudo modprobe btusb).
  boot.extraModprobeConfig = ''
    options btusb enable_autosuspend=N
  '';
}
