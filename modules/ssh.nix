# modules/ssh.nix
{ pkgs, ... }:

{
  # 1. Enable the OpenSSH daemon
  services.openssh = {
    enable = true;
    settings = {
      # For security, you can change the port (default is 22)
      # Port = 22;
      
      # Disable root login for security
      PermitRootLogin = "no";
      
      # Allow password authentication (Set to false if using SSH keys only)
      PasswordAuthentication = true;
    };
  };

  # 2. Open the firewall port
  # NixOS usually does this automatically when services.openssh is enabled, 
  # but it's good to be explicit.
  networking.firewall.allowedTCPPorts = [ 22 ];
}
