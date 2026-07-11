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
      from dbus_next.service import ServiceInterface, method, signal
      from dbus_next import BusType

      QS = ["${qsBin}", "ipc", "--config", "bar", "call", "notifications", "add"]

      class Notifications(ServiceInterface):
          def __init__(self):
              super().__init__("org.freedesktop.Notifications")
              self._next_id = 1
              self._actions = {}  # nid -> list of action keys (for ActionInvoked)

          # --- spec signals (emitted when the bar clicks / dismisses a card) ---
          @signal()
          def ActionInvoked(self, nid: "u", action: "s") -> "us":
              return [nid, action]

          @signal()
          def NotificationClosed(self, nid: "u", reason: "u") -> "uu":
              return [nid, reason]

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
              # Return a REAL id (Chromium matches ActionInvoked by this id). Honor
              # replaces_id so an app can update an existing notification in place.
              nid = replaces_id if replaces_id else self._next_id
              if not replaces_id:
                  self._next_id += 1
              # actions is a flat [key, label, key, label, ...]; keys are the evens.
              keys = actions[0::2] if actions else []
              self._actions[nid] = keys
              if len(self._actions) > 500:  # bound the id->actions map
                  del self._actions[next(iter(self._actions))]
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
                  "clickId": nid,
              })
              try:
                  subprocess.run(QS + [payload], check=False, timeout=5)
                  print("[quickshell-notify] " + str(app_name or "?") + " -> " + str(summary or "") + " (id=" + str(nid) + ", actions=" + str(len(keys)) + ")", flush=True)
              except Exception as e:
                  print("[quickshell-notify] forward failed: " + str(e), file=sys.stderr)
              return nid

          @method()
          def CloseNotification(self, id: "u") -> "":
              return

          # --- click-to-open support (called by the bar via NotifyBridge) ---
          def invoke(self, nid):
              keys = self._actions.get(nid, [])
              action = "default" if "default" in keys else (keys[0] if keys else None)
              if action is not None:
                  self.ActionInvoked(nid, action)
                  print("[quickshell-notify] ActionInvoked id=" + str(nid) + " action=" + str(action), flush=True)

          def dismiss(self, nid):
              if nid in self._actions:
                  self.NotificationClosed(nid, 3)  # 3 = dismissed by the user
                  del self._actions[nid]
                  print("[quickshell-notify] NotificationClosed id=" + str(nid), flush=True)


      class NotifyBridge(ServiceInterface):
          """Private side-channel the bar calls (via dbus-send) to forward a card
          click/dismiss back to the owning app as ActionInvoked / NotificationClosed.
          Exported on the same object as org.freedesktop.Notifications."""
          def __init__(self, notifications):
              super().__init__("org.quickshell.NotifyBridge")
              self._n = notifications

          @method()
          def Invoke(self, nid: "u") -> "":
              self._n.invoke(nid)

          @method()
          def Dismiss(self, nid: "u") -> "":
              self._n.dismiss(nid)


      async def main():
          bus = await MessageBus(bus_type=BusType.SESSION).connect()
          n = Notifications()
          bus.export("/org/freedesktop/Notifications", n)
          bus.export("/org/freedesktop/Notifications", NotifyBridge(n))
          res = await bus.request_name("org.freedesktop.Notifications")
          # request_name returns a RequestNameReply enum; PRIMARY_OWNER / ALREADY_OWNER = success
          if getattr(res, "name", str(res)) not in ("PRIMARY_OWNER", "ALREADY_OWNER"):
              print("[quickshell-notify] could not acquire name (result " + str(res) + ")", file=sys.stderr)
              sys.exit(1)
          print("[quickshell-notify] owning org.freedesktop.Notifications -> forwarding to quickshell (click-to-open enabled)", flush=True)
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
    };
    Service = {
      ExecStart = "${quickshellNotifyForwarder}/bin/quickshell-notify-forwarder";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install = {
      # Bind to default.target — it is ALWAYS active for a logged-in user.
      # Do NOT use graphical-session.target: on this Hyprland+NixOS setup that
      # target is never activated, so a graphical-session-bound service never
      # auto-starts (the silent-failure bug this corrects). The forwarder only
      # needs the session bus (always present) and the bar running for delivery.
      WantedBy = [ "default.target" ];
    };
  };
}
