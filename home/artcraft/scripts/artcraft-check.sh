# artcraft-check: compare the ACTIVATED ArtCraft versions with the newest GitHub release.
# Writes $XDG_STATE_HOME/artcraft/status.json for the Quickshell widget and artcraft-upgrade.
# Env (set by the Nix module): ARTCRAFT_VERSIONS_FILE, ARTCRAFT_INSTALLED_FILE
#
# status.json shape:
#   { checked, count, errors, error,
#     apps:     [ { app, displayName, repo, installed, latest, url, state } ],
#     outdated: [ ...same rows where state == "outdated" ] }
# state: current | outdated | waiting | error | unknown

versions_file="${ARTCRAFT_VERSIONS_FILE:?ARTCRAFT_VERSIONS_FILE not set}"
installed_file="${ARTCRAFT_INSTALLED_FILE:?ARTCRAFT_INSTALLED_FILE not set}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/artcraft"
status_file="$state_dir/status.json"
mkdir -p "$state_dir"

prev='{}'
if [ -f "$status_file" ]; then
  prev=$(cat "$status_file" 2>/dev/null || echo '{}')
fi
previous_count=$(jq -r '.count // 0' <<<"$prev" 2>/dev/null || echo 0)

installed='{}'
if [ -f "$installed_file" ]; then
  installed=$(cat "$installed_file")
fi

apps='[]'
outdated='[]'
errors=0
error_msg=""

while read -r app; do
  display=$(jq -r --arg a "$app" '.[$a].displayName // $a' "$versions_file")
  repo=$(jq -r --arg a "$app" '.[$a].repo // ""' "$versions_file")
  current=$(jq -r --arg a "$app" '.[$a] // ""' <<<"$installed")
  prev_app=$(jq -c --arg a "$app" \
    '((.apps // []) + (.outdated // [])) | map(select(.app == $a)) | .[0] // empty' \
    <<<"$prev" 2>/dev/null || true)

  if [ -z "$repo" ]; then
    errors=$((errors + 1))
    error_msg="missing repo for $app"
    apps=$(jq -c --arg app "$app" --arg dn "$display" --arg cur "$current" \
      '. + [{app:$app, displayName:$dn, repo:"", installed:$cur, latest:"", url:"", state:"error"}]' <<<"$apps")
    continue
  fi

  # /releases?per_page=1 (not /releases/latest) so pre-releases count: these apps are still beta.
  if ! release=$(curl -fsSL --max-time 20 \
        -H 'Accept: application/vnd.github+json' \
        "https://api.github.com/repos/$repo/releases?per_page=1" | jq -c '.[0] // empty'); then
    echo "artcraft-check: could not query $repo" >&2
    errors=$((errors + 1))
    error_msg="could not query $repo"
    if [ -n "$prev_app" ]; then
      apps=$(jq -c --argjson e "$prev_app" '. + [$e]' <<<"$apps")
    else
      apps=$(jq -c --arg app "$app" --arg dn "$display" --arg repo "$repo" --arg cur "$current" \
        '. + [{app:$app, displayName:$dn, repo:$repo, installed:$cur, latest:"", url:"", state:"error"}]' <<<"$apps")
    fi
    continue
  fi

  latest=$(jq -r '.tag_name // "" | ltrimstr("v")' <<<"$release")
  # Match *.AppImage only; this deliberately excludes the .AppImage.zsync companion file.
  url=$(jq -r '[.assets[]? | select(.name | test("linux-x86_64\\.AppImage$"))][0].browser_download_url // ""' <<<"$release")

  if [ -z "$latest" ]; then
    errors=$((errors + 1))
    error_msg="$repo has no release tag"
    state="error"
  elif [ -z "$url" ]; then
    # Release exists but CI has not uploaded the Linux AppImage yet; try again next run.
    echo "artcraft-check: $app has no Linux x86_64 AppImage yet, skipping" >&2
    state="waiting"
  elif [ -z "$current" ] || [ "$current" != "$latest" ]; then
    state="outdated"
  else
    state="current"
  fi

  entry=$(jq -cn --arg app "$app" --arg dn "$display" --arg repo "$repo" \
    --arg cur "$current" --arg lat "$latest" --arg url "$url" --arg state "$state" \
    '{app:$app, displayName:$dn, repo:$repo, installed:$cur, latest:$lat, url:$url, state:$state}')
  apps=$(jq -c --argjson e "$entry" '. + [$e]' <<<"$apps")
  if [ "$state" = "outdated" ]; then
    outdated=$(jq -c --argjson e "$entry" '. + [$e]' <<<"$outdated")
  fi
done < <(jq -r 'keys_unsorted[]' "$versions_file")

count=$(jq 'length' <<<"$outdated")

jq -n --argjson apps "$apps" --argjson outdated "$outdated" \
  --argjson count "$count" --argjson errors "$errors" --arg error "$error_msg" \
  --argjson checked "$(date +%s)" \
  '{checked:$checked, count:$count, errors:$errors, error:$error, apps:$apps, outdated:$outdated}' \
  >"$status_file.tmp"
mv "$status_file.tmp" "$status_file"

if [ "$count" -gt 0 ] && [ "$count" -ne "$previous_count" ]; then
  names=$(jq -r 'map(.displayName + " " + .latest) | join(", ")' <<<"$outdated")
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -a ArtCraft "ArtCraft updates available" "$names" || true
  fi
fi

echo "artcraft-check: $count update(s) available"
