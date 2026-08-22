#!/usr/bin/env python3
"""junos-mcp — read-only Junos device state over MCP (FastMCP + PyEZ).

Bridges coding agents (opencode, Claude Code) to the Juniper lab so a model
can SEE live network state ("why did BGP flap on p3?") without raw SSH.

  Inventory:   ~/.config/junos-mcp/routers.json   [{"name","host","port"}]
  Credentials: ~/.config/secrets/junos.env        JUNOS_USER / JUNOS_PASSWORD
               (env vars override the file — the file follows the omni-nix
               out-of-tree secrets convention; never commit either)

READ-ONLY by design: every RPC here is a `show`-equivalent, and run_op is
allowlisted to `show`/`op` commands. Config changes do NOT belong in an
agent's hands — restor8's connector owns that workflow, with confirmed
commits and JSNAPy gates.
"""

from __future__ import annotations

import json
import os
import pathlib
import re

# Official MCP SDK's FastMCP (not the `fastmcp` package): nixpkgs' pydantic
# 2.12 breaks fastmcp 3.2.3's tools/call dispatch (JSONRPCMessage validation
# errors); the SDK and pydantic are pinned together in nixpkgs, so they
# always match.
from mcp.server.fastmcp import FastMCP
from jnpr.junos import Device
from jnpr.junos.exception import ConnectError

HOME = pathlib.Path.home()
INVENTORY_PATH = HOME / ".config/junos-mcp/routers.json"
CREDS_PATH = HOME / ".config/secrets/junos.env"
RPC_TIMEOUT = 30
# read-only CLI surface for run_op; anything else (configure, request,
# commit, start-shell…) is refused before it ever reaches a device.
ALLOWED_OP = re.compile(r"^(show|op)\b", re.IGNORECASE)


def _kv_file(path: pathlib.Path) -> dict[str, str]:
    if not path.exists():
        return {}
    out: dict[str, str] = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, val = line.split("=", 1)
            out[key.strip()] = val.strip()
    return out


def _inventory() -> dict[str, dict]:
    if not INVENTORY_PATH.exists():
        return {}
    rows = json.loads(INVENTORY_PATH.read_text())
    return {r["name"]: r for r in rows}


def _connect(name: str) -> Device:
    inv = _inventory()
    if name not in inv:
        known = ", ".join(sorted(inv)) or "(inventory empty — see ~/.config/junos-mcp/routers.json)"
        raise ValueError(f"unknown router {name!r}; known: {known}")
    entry = inv[name]
    env = _kv_file(CREDS_PATH)
    user = os.environ.get("JUNOS_USER") or env.get("JUNOS_USER")
    password = os.environ.get("JUNOS_PASSWORD") or env.get("JUNOS_PASSWORD")
    if not user or not password:
        raise ValueError(
            "credentials missing: put JUNOS_USER / JUNOS_PASSWORD in "
            "~/.config/secrets/junos.env (or export them)"
        )
    dev = Device(
        host=entry["host"],
        port=int(entry.get("port", 830)),
        user=user,
        password=password,
        gather_facts=False,
    )
    dev.open(gather_facts=False, auto_probe=2)
    dev.timeout = RPC_TIMEOUT
    return dev


def _rpc(router: str, call) -> str:
    """Run call(dev) on a fresh connection; errors become readable strings."""
    try:
        dev = _connect(router)
    except Exception as exc:  # noqa: BLE001 — errors are the tool's output
        return f"ERROR ({router}): {exc}"
    try:
        return call(dev)
    except Exception as exc:  # noqa: BLE001
        return f"ERROR ({router}) during RPC: {exc}"
    finally:
        try:
            dev.close()
        except Exception:  # noqa: BLE001
            pass


def _text(obj) -> str:
    """Serialize an lxml RPC reply; prefer CLI text when the RPC produced it."""
    txt = "".join(obj.itertext()).strip()
    return txt or obj.tag or "(empty reply)"


mcp = FastMCP("junos")


@mcp.tool()
def list_routers() -> str:
    """List the inventory (name, host:port). Call this first to get names."""
    inv = _inventory()
    if not inv:
        return (
            "inventory empty or missing: ~/.config/junos-mcp/routers.json "
            '(format: [{"name": "p1", "host": "10.0.0.29", "port": 32001}])'
        )
    return "\n".join(
        f"{name}: {r['host']}:{r.get('port', 830)}" for name, r in sorted(inv.items())
    )


@mcp.tool()
def get_facts(router: str) -> str:
    """Device identity + software (equivalent to: show version)."""
    return _rpc(router, lambda dev: _text(dev.rpc.get_software_information()))


@mcp.tool()
def get_bgp_summary(router: str) -> str:
    """BGP neighbor state (equivalent to: show bgp summary)."""
    return _rpc(router, lambda dev: _text(dev.rpc.get_bgp_summary_information()))


@mcp.tool()
def get_interfaces_terse(router: str) -> str:
    """Interface table (equivalent to: show interfaces terse)."""
    return _rpc(
        router,
        lambda dev: _text(dev.rpc.get_interface_information(terse=True)),
    )


@mcp.tool()
def get_config(router: str, fmt: str = "set") -> str:
    """Running configuration (equivalent to: show configuration | display set).

    fmt: "set" (diffable, safest) or "text" (hierarchical).
    """
    if fmt not in ("set", "text"):
        return 'ERROR: fmt must be "set" or "text"'

    def call(dev: Device) -> str:
        # equivalent to: show configuration | display set   (fmt="set")
        # equivalent to: show configuration                 (fmt="text")
        return _text(dev.rpc.get_config(options={"format": fmt}))

    return _rpc(router, call)


@mcp.tool()
def run_op(router: str, command: str) -> str:
    """Run a READ-ONLY operational command (must start with `show` or `op`).

    Everything else — configure, commit, request, start-shell — is refused.
    """
    if not ALLOWED_OP.match(command.strip()):
        return (
            f"REFUSED: {command!r} — run_op is allowlisted to `show`/`op` "
            "commands only. Config changes go through restor8's connector."
        )
    return _rpc(router, lambda dev: dev.cli(command.strip(), format="text", warning=False))


if __name__ == "__main__":
    mcp.run()
