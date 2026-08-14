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

  # ── Force the RNDIS USB configuration (the Windows path) ────────────────
  # The pwni gadget exposes TWO configurations:
  #   config 1 = CDC-ECM  — Linux's default choice (cdc_ether). WEDGES on the
  #                         Pi side after seconds-to-minutes: NETDEV WATCHDOG
  #                         tx timeouts, dead ARP, control transfers time out.
  #   config 2 = RNDIS    — what Windows binds (rndis_host). ROCK SOLID.
  # (Verified 2026-08-14: config 2 pinged 0% loss, sshd reachable.)
  # This rule flips every enumeration of 2e8a:0013 (Raspberry Pi USB Gadget)
  # to config 2 BEFORE any driver binds, so the wedged CDC-ECM path is never
  # taken — no more manual sysfs writes after replug or reboot.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="2e8a", ATTR{idProduct}=="0013", ATTR{bConfigurationValue}="2"
  '';

  # ── Keep WiFi as the only internet path while the pwni is plugged in ────
  # The pwni's DHCP hands out ITSELF as gateway+DNS. NM prefers wired routes
  # (metric 100) over wifi (600), so when the gadget link is up its default
  # route wins and all internet traffic drowns in a Pi with no uplink —
  # "connected to pwnagotchi = lose the internet". This dispatcher marks any
  # USB-gadget-ethernet connection (by DRIVER, since the interface name and
  # MAC change on every enumeration) as never-default + ignore-auto-dns.
  # The on-link 10.12.x subnet route is untouched — ssh to the pwni still works.
  # ── Internet sharing: the desktop becomes the pwni's router ─────────────
  # Forwards + masquerades the gadget subnet out through whatever the current
  # uplink is (WiFi today, ethernet tomorrow), so the pwni can apt update /
  # install plugins. The pwni-side counterpart is a default route + DNS there
  # (see module header). Forwarding is global; the rules are per-subnet.
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = pkgs.writeText "pwnagotchi-gadget-policy" ''
        IPT=${pkgs.iptables}/bin/iptables

        mark_gadget_connection() {
          # never-default + ignore-auto-dns: keep WiFi as the only internet path
          nmcli connection modify id "$CONN" \
            ipv4.never-default yes \
            ipv6.never-default yes \
            ipv4.ignore-auto-dns yes \
            ipv6.ignore-auto-dns yes
        }

        nat_setup() {
          # NAT the pwni's on-link subnet (computed live — it changes per boot)
          # out through any interface EXCEPT the gadget itself.
          SUB=$(ip -4 route show dev "$DEV" | awk '/scope link/ {print $1; exit}')
          [ -n "$SUB" ] || return 0
          echo "$SUB" > "/run/pwni-subnet-$DEV" 2>/dev/null
          $IPT -t nat -C POSTROUTING -s "$SUB" ! -o "$DEV" -j MASQUERADE 2>/dev/null || \
            $IPT -t nat -A POSTROUTING -s "$SUB" ! -o "$DEV" -j MASQUERADE
          # docker's FORWARD policy is DROP — let the pwni's flows through
          $IPT -C FORWARD -i "$DEV" -j ACCEPT 2>/dev/null || \
            $IPT -A FORWARD -i "$DEV" -j ACCEPT
          $IPT -C FORWARD -o "$DEV" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
            $IPT -A FORWARD -o "$DEV" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        }

        nat_teardown() {
          SUB=$(cat "/run/pwni-subnet-$DEV" 2>/dev/null)
          [ -n "$SUB" ] && $IPT -t nat -D POSTROUTING -s "$SUB" ! -o "$DEV" -j MASQUERADE 2>/dev/null
          rm -f "/run/pwni-subnet-$DEV" 2>/dev/null
          $IPT -D FORWARD -i "$DEV" -j ACCEPT 2>/dev/null
          $IPT -D FORWARD -o "$DEV" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null
        }

        if [ "$2" = "up" ] || [ "$2" = "dhcp4-change" ]; then
          DEV="$1"
          if [ -e "/sys/class/net/$DEV/device/driver" ]; then
            DRV=$(basename "$(readlink "/sys/class/net/$DEV/device/driver")")
            case "$DRV" in
              cdc_ether|rndis_host|cdc_ncm)
                CONN=$(nmcli -g GENERAL.CONNECTION device show "$DEV" 2>/dev/null)
                [ -n "$CONN" ] && mark_gadget_connection
                nat_setup
                ;;
            esac
          fi
        elif [ "$2" = "down" ]; then
          DEV="$1"
          if [ -e "/sys/class/net/$DEV/device/driver" ]; then
            DRV=$(basename "$(readlink "/sys/class/net/$DEV/device/driver")")
            case "$DRV" in
              cdc_ether|rndis_host|cdc_ncm) nat_teardown ;;
            esac
          fi
        fi
        exit 0
      '';
    }
  ];

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
