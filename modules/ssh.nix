# modules/ssh.nix
# =============================================================================
# SSH daemon: ENABLED  (inbound SSH open, password auth)
# =============================================================================
# Re-enabled 2026-10-30 so nikos can ssh INTO this machine from LAN devices.
# Password authentication is ON (reuses the account password set with `passwd`,
# so new devices need no key provisioning). Root stays key-only
# (`prohibit-password`, the NixOS default) so root is not password-brute-forceable.
#
# openFirewall opens tcp/22 on networking.firewall. NOTE: this module is shared —
# hosts/desktop AND hosts/dell3440 both import it, so BOTH machines accept
# inbound SSH after this change.
#
# To harden later (key-only):
#   1. settings.PasswordAuthentication = false
#   2. users.users.nikos.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA..." ];
# =============================================================================
{ pkgs, ... }:

{
  # Inbound SSH daemon (see header).
  services.openssh.enable = true;

  services.openssh.settings = {
    # Account password (`passwd`) is accepted for nikos logins.
    PasswordAuthentication = true;
    # Root: keys only, never passwords (NixOS default — kept explicit).
    PermitRootLogin = "prohibit-password";
  };

  # Open tcp/22 on the firewall (adds to networking.firewall.allowedTCPPorts).
  services.openssh.openFirewall = true;

  # Outbound SSH client (ssh/scp/sftp). The daemon's package also provides it,
  # but the explicit install keeps outbound ssh (github pushes via id_github)
  # working independently of the daemon state.
  environment.systemPackages = [ pkgs.openssh ];
}
