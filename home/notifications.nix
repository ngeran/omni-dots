# =============================================================================
# notifications.nix — bridge org.freedesktop.Notifications into the Quickshell bar
# =============================================================================
# Quickshell 0.3.0 has no QML DBus-server API, so it cannot OWN the
# org.freedesktop.Notifications name itself. Without an owner, apps (Chromium,
# notify-send, etc.) have nowhere to send notifications → Chromium falls back to
# its own popup window (the "full terminal window" YouTube notifications).
#
# This tiny forwarder daemon owns the name on the session bus and pipes every
# Notify call into the bar's NotificationService via Quickshell IPC:
#   quickshell ipc --config bar call notifications add '<json>'
#
# Verified working end-to-end (dbus-next sender → forwarder → IPC rc=0) before
# being wired here. Owned by the graphical session, auto-restarted on failure.
# =============================================================================
{ config, pkgs, ... }:

let
  # Absolute path to the quickshell binary (home-manager symlink). The systemd
  # user service does not inherit the interactive shell PATH, so resolve it here.
  qsBin = "/etc/profiles/per-user/${config.home.username}/bin/quickshell";

  quickshellNotifyForwarder = pkgs.writers.writePython3Bin "quickshell-notify-forwarder"
    {
      libraries = [ pkgs.python3Packages.dbus-next ];
      # F821/F722 are false positives: dbus-next reads DBus type signatures
      # ("s","u","i","as","a{sv}") from string annotations, which pyflakes
      # tries to resolve as Python names. E302/E401/E501 are style nits.
      # Full set verified via `nix shell nixpkgs#flake8` — no others remain.
      flakeIgnore = [ "E501" "E402" "W503" "F821" "F722" "E302" "E401" ];
    }
    ''
      import json, subprocess, sys, asyncio
      from dbus_next.aio import MessageBus
      from dbus_next.service import ServiceInterface, method
      from dbus_next import BusType

      QS = ["${qsBin}", "ipc", "--config", "bar", "call", "notifications", "add"]

      class Notifications(ServiceInterface):
          def __init__(self):
              super().__init__("org.freedesktop.Notifications")

          @method()
          def GetServerInformation(self) -> "ssss":
              return ("quickshell", "quickshell-notify", "1.0", "1.2")

          @method()
          def GetCapabilities(self) -> "as":
              return ["body", "actions"]

          @method()
          def Notify(self, app_name: "s", replaces_id: "u", app_icon: "s",
                     summary: "s", body: "s", actions: "as", hints: "a{sv}",
                     expire_timeout: "i") -> "u":
              urgency = 1
              try:
                  u = hints.get("urgency")
                  if u is not None:
                      urgency = int(u.value if hasattr(u, "value") else u)
              except Exception:
                  pass
              payload = json.dumps({
                  "appName": app_name or "Notification",
                  "summary": summary or "",
                  "body": body or "",
                  "urgency": urgency,
              })
              try:
                  subprocess.run(QS + [payload], check=False, timeout=5)
              except Exception as e:
                  print("[quickshell-notify] forward failed: " + str(e), file=sys.stderr)
              return 0

          @method()
          def CloseNotification(self, id: "u") -> "":
              return

      async def main():
          bus = await MessageBus(bus_type=BusType.SESSION).connect()
          bus.export("/org/freedesktop/Notifications", Notifications())
          res = await bus.request_name("org.freedesktop.Notifications")
          # request_name returns a RequestNameReply enum; PRIMARY_OWNER / ALREADY_OWNER = success
          if getattr(res, "name", str(res)) not in ("PRIMARY_OWNER", "ALREADY_OWNER"):
              print("[quickshell-notify] could not acquire name (result " + str(res) + ")", file=sys.stderr)
              sys.exit(1)
          print("[quickshell-notify] owning org.freedesktop.Notifications -> forwarding to quickshell", flush=True)
          await bus.wait_for_disconnect()

      if __name__ == "__main__":
          asyncio.run(main())
    '';
in
{
  # Expose the script on PATH too (manual testing / debugging).
  home.packages = [ quickshellNotifyForwarder ];

  systemd.user.services.quickshell-notify = {
    Unit = {
      Description = "Quickshell notification forwarder (org.freedesktop.Notifications -> bar IPC)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${quickshellNotifyForwarder}/bin/quickshell-notify-forwarder";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
