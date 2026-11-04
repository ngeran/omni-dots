# artcraft-upgrade: bump versions.json for the selected apps, then rebuild.
# Usage: artcraft-upgrade [app ...]     (no args = every outdated app)
#
# Progress is written atomically to $XDG_STATE_HOME/artcraft/progress.json:
#   { running, active, overall, message, error, updated,
#     apps: { <app>: { phase, percent, message } } }
# Download percent is real; hash/pin/rebuild are phase-based. The Quickshell
# service reads this file, so it survives a bar restart during the rebuild.
#
# Env (set by the Nix module): ARTCRAFT_VERSIONS_FILE, ARTCRAFT_SWITCH

versions_file="${ARTCRAFT_VERSIONS_FILE:?ARTCRAFT_VERSIONS_FILE not set}"
switch_cmd="${ARTCRAFT_SWITCH:-/etc/artcraft-switch}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/artcraft"
status_file="$state_dir/status.json"
progress_file="$state_dir/progress.json"
mkdir -p "$state_dir" "$state_dir/downloads"

# One upgrade at a time (timer + manual click could otherwise overlap).
exec 9>"$state_dir/upgrade.lock"
if ! flock -n 9; then
  echo "another upgrade is already running"
  exit 1
fi

apps_progress='{}'
count=0

progress_write() {
  local running="$1" active="$2" overall="$3" message="$4" error="$5"
  jq -n --argjson running "$running" --arg active "$active" \
    --argjson overall "$overall" --arg message "$message" --arg error "$error" \
    --argjson updated "$(date +%s)" --argjson apps "$apps_progress" \
    '{running:$running, active:$active, overall:$overall, message:$message,
      error:$error, updated:$updated, apps:$apps}' >"$progress_file.tmp"
  mv "$progress_file.tmp" "$progress_file"
}

set_app() {
  local app="$1" phase="$2" percent="$3" message="$4"
  apps_progress=$(jq -c --arg a "$app" --arg ph "$phase" --argjson pct "$percent" --arg msg "$message" \
    '.[$a] = {phase:$ph, percent:$pct, message:$msg}' <<<"$apps_progress")
}

overall_for() {
  local completed="$1" pct="$2" total="$3"
  if [ "$total" -le 0 ]; then echo 0; return; fi
  echo $(( (completed * 100 + pct) * 80 / (total * 100) ))
}

fail_all() {
  local message="$1"
  local app
  for app in $(jq -r 'keys[]' <<<"$apps_progress" 2>/dev/null || true); do
    set_app "$app" error 100 "$message"
  done
  progress_write false "" 100 "Failed" "$message"
  echo "==> $message" >&2
}

download_app() {
  local app="$1" url="$2" display="$3" latest="$4" completed="$5"
  local tmpfile="$state_dir/downloads/$app.AppImage"
  local total size pct overall

  rm -f "$tmpfile"
  total=$(curl -fsIL --max-time 30 "$url" 2>/dev/null \
    | awk 'BEGIN{IGNORECASE=1}/^content-length:/{gsub("\r","",$2); v=$2}END{print v+0}')

  echo "==> $app: downloading $url"
  set_app "$app" download 0 "Downloading $display $latest"
  progress_write true "$app" "$(overall_for "$completed" 0 "$count")" \
    "Downloading $display $latest" ""

  curl -fL --retry 2 --silent --show-error -o "$tmpfile" "$url" &
  local pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    size=$(stat -c%s "$tmpfile" 2>/dev/null || echo 0)
    if [ "$total" -gt 0 ]; then pct=$((size * 100 / total)); else pct=0; fi
    [ "$pct" -gt 100 ] && pct=100
    set_app "$app" download "$pct" "Downloading $display $latest"
    overall=$(overall_for "$completed" "$pct" "$count")
    progress_write true "$app" "$overall" "Downloading $display $latest" ""
    sleep 0.5
  done

  if ! wait "$pid"; then
    fail_all "download failed for $app"
    return 1
  fi

  set_app "$app" download 100 "Downloaded $display $latest"
  progress_write true "$app" "$(overall_for "$completed" 100 "$count")" \
    "Downloaded $display $latest" ""
}

echo "==> checking GitHub releases"
if ! artcraft-check; then
  fail_all "artcraft-check failed"
  exit 1
fi

if [ "$#" -gt 0 ]; then
  names_json=$(printf '%s\n' "$@" | jq -R . | jq -s .)
  targets_json=$(jq -c --argjson names "$names_json" \
    '[.outdated[] | select(.app as $a | $names | index($a))]' "$status_file")
else
  targets_json=$(jq -c '.outdated' "$status_file")
fi

count=$(jq 'length' <<<"$targets_json")
if [ "$count" -eq 0 ]; then
  echo "==> everything is up to date"
  progress_write false "" 100 "Everything is up to date" ""
  exit 0
fi

apps_progress=$(jq -c '[.[] | {key:.app, value:{phase:"pending", percent:0, message:""}}] | from_entries' \
  <<<"$targets_json")
progress_write true "" 0 "Starting" ""

completed=0
while read -r entry; do
  app=$(jq -r '.app' <<<"$entry")
  display=$(jq -r '.displayName // .app' <<<"$entry")
  installed=$(jq -r '.installed | if . == "" then "none" else . end' <<<"$entry")
  latest=$(jq -r '.latest' <<<"$entry")
  url=$(jq -r '.url' <<<"$entry")

  echo "==> $app: $installed -> $latest"

  pinned_version=$(jq -r --arg a "$app" '.[$a].version // ""' "$versions_file")
  pinned_url=$(jq -r --arg a "$app" '.[$a].url // ""' "$versions_file")
  pinned_hash=$(jq -r --arg a "$app" '.[$a].hash // ""' "$versions_file")

  if [ "$pinned_version" = "$latest" ] && [ "$pinned_url" = "$url" ] && [ -n "$pinned_hash" ]; then
    echo "    already pinned at $latest — skipping download"
    set_app "$app" pin 90 "Already pinned $display $latest"
    progress_write true "$app" "$(overall_for "$completed" 100 "$count")" \
      "Pinned $display $latest" ""
  else
    if ! download_app "$app" "$url" "$display" "$latest" "$completed"; then
      exit 1
    fi

    echo "    hashing $app"
    set_app "$app" hash 85 "Hashing $display $latest"
    progress_write true "$app" "$(overall_for "$completed" 100 "$count")" \
      "Hashing $display $latest" ""
    hash=$(nix hash file --type sha256 --sri "$state_dir/downloads/$app.AppImage")

    echo "    pinning $app $latest ($hash)"
    set_app "$app" pin 90 "Pinning $display $latest"
    progress_write true "$app" "$(overall_for "$completed" 100 "$count")" \
      "Pinning $display $latest" ""

    tmp=$(mktemp)
    jq --arg a "$app" --arg v "$latest" --arg u "$url" --arg h "$hash" \
      '.[$a] |= (.version = $v | .url = $u | .hash = $h)' "$versions_file" >"$tmp"
    cat "$tmp" >"$versions_file"
    rm -f "$tmp" "$state_dir/downloads/$app.AppImage"
  fi

  completed=$((completed + 1))
  set_app "$app" "done" 100 "Installed $display $latest"
  progress_write true "$app" "$(overall_for "$completed" 0 "$count")" \
    "Pinned $display $latest" ""
done < <(jq -c '.[]' <<<"$targets_json")

echo "==> rebuilding system with $switch_cmd"
progress_write true "" 82 "Rebuilding system" ""

if ! command -v sudo >/dev/null 2>&1; then
  fail_all "sudo not found"
  exit 1
fi

if sudo -n "$switch_cmd"; then
  echo "==> switch complete"
  progress_write true "" 95 "Re-checking versions" ""
  artcraft-check >/dev/null || true
  progress_write false "" 100 "Done" ""
  echo "==> done"
else
  fail_all "rebuild failed — is the artcraft-switch sudo rule installed?"
  exit 1
fi
