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
}
