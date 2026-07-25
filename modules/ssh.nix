# modules/ssh.nix
# =============================================================================
# SSH daemon: DISABLED  (inbound SSH closed)
# =============================================================================
# Nothing SSHes INTO this desktop — zero inbound auth events in 7+ days and no
# authorized keys (the only key in ~/.ssh is `id_github`, an OUTBOUND key for git
# pushes). Running an unused sshd is a needless brute-force surface, so the
# daemon is OFF and port 22 is CLOSED. This is stronger than hardening an unused
# service — there is no door to attack.
#
# The OUTBOUND ssh client stays available (installed explicitly below) so github
# pushes / `ssh git@github.com` keep working — only inbound access is removed.
#
# To re-enable REMOTE (inbound) access later:
#   1. services.openssh.enable = true
#   2. add an authorized key (prefer key-only — also set PasswordAuthentication=false):
#        users.users.nikos.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA..." ];
#   3. re-open the firewall: networking.firewall.allowedTCPPorts = [ 22 ];
#   4. omni-apply
# =============================================================================
{ pkgs, ... }:

{
  # Inbound SSH daemon: OFF (see header). No firewall opening for port 22 — it
  # stays closed. (services.openssh.openFirewall defaults to false anyway, and
  # we no longer add 22 to allowedTCPPorts.)
  services.openssh.enable = false;

  # Outbound SSH client (ssh/scp/sftp). `services.openssh.enable = true` added
  # this while the daemon was on; with the daemon off, install it explicitly so
  # outbound ssh (github pushes via id_github) keeps working.
  environment.systemPackages = [ pkgs.openssh ];
}
