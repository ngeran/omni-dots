{ pkgs, ... }:

# =============================================================================
# Pwnagotchi host-side connectivity (USB OTG + mDNS)
# =============================================================================
# Per the jayofelony/pwnagotchi wiki "Step 2: Connecting":
#   https://github.com/jayofelony/pwnagotchi/wiki/Step-2-Connecting
#
# The Pi (flashed SD inserted) is plugged into this machine with a DATA usb
# cable in OTG mode and enumerates as a USB ETHERNET GADGET. The host needs:
#   • kernel modules for the gadget — cdc_ether (CDC-ECM, the Linux default)
#     or rndis_host (RNDIS, used when the pwni is configured for Windows
#     compat). They normally auto-load on hotplug; we pin them at boot so the
#     interface (usb0 / enx<mac>) always appears.
#   • avahi-daemon + nss-mdns so `ssh pi@<hostname>.local` resolves.
#
# The OUTBOUND ssh client is already installed system-wide (modules/ssh.nix) —
# the inbound sshd stays off, which is fine: we ssh OUT to the pwni.
#
# Connecting (first time):
#   1. Plug the data USB cable into the correct OTG port on the Pi
#      (Pi0W/Pi02W: the micro-USB closest to HDMI; Pi4/5: USB-C).
#   2. `lsusb` should show a new gadget device; an usb0/enx… interface appears
#      (NetworkManager picks it up and DHCPs — the pwni runs a DHCP server on
#      the gadget link, so the host lands in the pwni's /24 automatically).
#   3. SSH in:            ssh pi@10.12.194.1        (direct gadget IP)
#      or via mDNS:       ssh pi@<hostname>.local
#      Default password:  raspberry
#   4. If DHCP didn't hand out an address (older pwni images), set a static
#      IPv4 on the NM connection instead, e.g. 10.12.194.2/24, gateway none —
#      then ssh pi@10.12.194.1.
#   5. avahi-discover from the wiki = GUI tool; the CLI equivalent here is
#      `avahi-browse -art` (lists everything reachable via mDNS).
# =============================================================================

{
  # mDNS / .local resolution (avahi-daemon + nss-mdns)
  services.avahi = {
    enable = true;
    nssmdns4 = true; # resolve <hostname>.local via multicast DNS
    publish = {
      enable = true;
      addresses = true; # announce this host too, so the pwni can find us
    };
  };

  # mDNS runs over multicast UDP 5353 — open it so discovery works in both
  # directions (no-op if the firewall is disabled).
  networking.firewall.allowedUDPPorts = [ 5353 ];

  # USB ethernet gadget drivers for the pwnagotchi OTG link
  boot.kernelModules = [ "cdc_ether" "rndis_host" "cdc_ncm" ];

  environment.systemPackages = with pkgs; [
    avahi # avahi-browse / avahi-resolve CLI helpers
    usbutils # lsusb — confirm the Pi enumerated over USB
  ];
}
