# modules/apps/junos-mcp — read-only Junos MCP server (FastMCP + PyEZ)
#
# Lets opencode / Claude Code SEE live lab state ("show bgp summary on p3")
# through typed tools instead of raw SSH. READ-ONLY by design: show/op only;
# config changes belong to restor8's connector (confirmed commits + JSNAPy).
#
# Runtime files (user-owned, NOT nix-managed):
#   ~/.config/junos-mcp/routers.json   inventory (an example is deployed
#                                       next to it as routers.json.example)
#   ~/.config/secrets/junos.env        JUNOS_USER / JUNOS_PASSWORD
#
# PyEZ is vendored via buildPythonPackage — nixpkgs doesn't package
# junos-eznc; the sdist hash is lifted verbatim from restor8's uv.lock
# (same artifact, already verified in production there).
{ pkgs, lib, ... }:

let
  ps = pkgs.python3Packages;

  pyez = ps.buildPythonPackage rec {
    pname = "junos-eznc";
    version = "2.8.2";
    format = "setuptools"; # 26.05 requires the format declared explicitly
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/34/66/aeab71e5844ff25b771c509b19f8c85e0e5d1c34851b52135de3e9609b9c/junos_eznc-${version}.tar.gz";
      hash = "sha256-uwQm50vORURAVyOpBHNB7ekbKc2bYfG+nmM6VcRw//w=";
    };
    # Full runtime set per restor8's uv.lock (buildPythonPackage does not
    # read setup.py install_requires — everything must be listed here).
    propagatedBuildInputs = with ps; [
      ncclient
      paramiko
      lxml
      pyyaml
      jinja2
      scp
      pyserial
      pyparsing
      six
      transitions
      yamlloader
    ];
    doCheck = false; # test suite wants live devices
  };

  env = pkgs.python3.withPackages (p: [
    p.mcp # official MCP SDK (includes FastMCP); see server.py import note
    pyez
  ]);

  junos-mcp = pkgs.writeShellScriptBin "junos-mcp" ''
    exec ${env}/bin/python ${pkgs.writeText "junos-mcp-server.py" (builtins.readFile ./server.py)} "$@"
  '';
in
{
  config = lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
    home.packages = [ junos-mcp ];

    # The MCP registration itself lives in modules/apps/opencode.nix
    # (mcp.junos, name-launched so it resolves via the HM profile PATH).
    xdg.configFile."junos-mcp/routers.json.example".text = builtins.toJSON [
      { name = "p1"; host = "10.0.0.29"; port = 32001; }
      { name = "p2"; host = "10.0.0.29"; port = 32002; }
    ];
  };
}
