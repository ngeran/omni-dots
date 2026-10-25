#!/usr/bin/env bash
# wallpaper-engine — animated wallpaper rotation for Hyprland (mpvpaper + mpv IPC)
#
# Modes:
#   standalone (WE_AUTOSTART=1, default) — the daemon owns rotation and walks
#     its playlist on WE_INTERVAL.
#   integrated (WE_AUTOSTART=0, this host) — Quickshell's WallpaperService owns
#     rotation and picks every file via `set`; the daemon is a pure watchdog
#     that keeps mpvpaper instances alive (crash, monitor hotplug) and never
#     advances on its own.
#
# Commands:
#   daemon            run the rotation/watchdog loop (what the systemd user service runs)
#   next | prev       skip forward / back immediately
#   pause | resume | toggle
#   set FILE          show FILE right now (heals dead instances, then loadfile)
#   clear             kill all mpvpaper instances and forget the last media (daemon stays up)
#   status            one-line JSON (for Quickshell)
#   list              print the current playlist
#   convert           pre-convert GIF/WebP/APNG to cached H.264 MP4 + OLED static-stretch scan
#   stop              stop the daemon and all mpvpaper instances
#
# Config (environment, all optional):
#   WE_DIR, WE_INTERVAL, WE_TICK, WE_HWDEC, WE_GAMMA, WE_PANSCAN,
#   WE_OUTPUTS, WE_SHUFFLE, WE_AUTOSTART, WE_EXTRA_MPV_OPTS

set -Eeuo pipefail

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

WE_DIR="${WE_DIR:-$HOME/Pictures/Live-Wallpapers}"
WE_INTERVAL="${WE_INTERVAL:-900}"   # seconds per wallpaper
WE_TICK="${WE_TICK:-20}"            # watchdog granularity in seconds
WE_HWDEC="${WE_HWDEC:-auto-safe}"   # try: nvdec, nvdec-copy, no
WE_GAMMA="${WE_GAMMA:-0}"           # -100..100, negative dims midtones, keeps true black
WE_PANSCAN="${WE_PANSCAN:-1.0}"     # 1.0 = fill screen (crop), 0 = letterbox
WE_OUTPUTS="${WE_OUTPUTS:-}"        # space-separated; empty = autodetect via hyprctl
WE_SHUFFLE="${WE_SHUFFLE:-1}"
WE_AUTOSTART="${WE_AUTOSTART:-1}"   # 0 = integrated mode: Quickshell drives, daemon only watches
WE_EXTRA_MPV_OPTS="${WE_EXTRA_MPV_OPTS:-}"

RUNTIME="$XDG_RUNTIME_DIR/wallpaper-engine"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper-engine"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-engine"
PIDFILE="$RUNTIME/daemon.pid"
mkdir -p "$RUNTIME" "$STATE" "$CACHE"

PLAYLIST=()
STEP=1
SKIP=0

log() { printf '[wallpaper-engine] %s\n' "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

# --- environment (systemd user services don't inherit Hyprland's env) -------
fix_env() {
  export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
  if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} && -d $XDG_RUNTIME_DIR/hypr ]]; then
    local sig
    sig=$(find "$XDG_RUNTIME_DIR/hypr" -maxdepth 1 -type d -printf '%T@ %f\n' 2>/dev/null \
          | sort -rn | head -n1 | cut -d' ' -f2)
    if [[ -n $sig ]]; then export HYPRLAND_INSTANCE_SIGNATURE="$sig"; fi
  fi
}

list_outputs() {
  if [[ -n $WE_OUTPUTS ]]; then
    tr ' ' '\n' <<<"$WE_OUTPUTS"
  else
    hyprctl monitors -j 2>/dev/null | jq -r '.[].name' || true
  fi
}

# --- media ------------------------------------------------------------------
convert_to_mp4() {
  local src=$1 key out
  key=$(printf '%s' "$src$(stat -c '%Y:%s' "$src")" | sha1sum | cut -c1-12)
  out="$CACHE/$(basename "${src%.*}")-$key.mp4"
  if [[ ! -s $out ]]; then
    log "converting $src"
    # $$ in the tmp name: a `convert` run racing the daemon must not clobber
    # the same partial file.
    if ! ffmpeg -nostdin -loglevel error -y -i "$src" -an \
          -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p -movflags +faststart \
          -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" "$out.tmp.$$.mp4" \
       || ! mv "$out.tmp.$$.mp4" "$out"; then
      rm -f "$out.tmp.$$.mp4"
      return 1
    fi
  fi
  printf '%s\n' "$out"
}

resolve_media() {
  local f=$1 ext
  ext="${f##*.}"; ext="${ext,,}"
  case $ext in
    gif|webp|apng) convert_to_mp4 "$f" ;;
    *) printf '%s\n' "$f" ;;
  esac
}

build_playlist() {
  [[ -d $WE_DIR ]] || die "wallpaper directory not found: $WE_DIR"
  mapfile -t PLAYLIST < <(find -L "$WE_DIR" -maxdepth 1 -type f \( \
    -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \
    -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.apng' \) | sort)
  (( ${#PLAYLIST[@]} > 0 )) || die "no media found in $WE_DIR"
  if [[ $WE_SHUFFLE == 1 ]]; then
    mapfile -t PLAYLIST < <(printf '%s\n' "${PLAYLIST[@]}" | shuf)
  fi
}

# --- mpvpaper instances (one per output, each with its own IPC socket) -------
alive() {
  local p="$RUNTIME/$1.pid"
  [[ -f $p ]] && kill -0 "$(<"$p")" 2>/dev/null
}

ipc_sock() { # SOCKET JSON
  printf '%s\n' "$2" | socat -t 0.3 - "UNIX-CONNECT:$1" >/dev/null 2>&1 || true
}

each_sock() { # CMD ARGS... (socket appended)
  local s
  for s in "$RUNTIME"/*.sock; do
    if [[ -S $s ]]; then "$@" "$s"; fi
  done
}

start_instance() { # OUTPUT MEDIA
  local out=$1 media=$2 sock="$RUNTIME/$1.sock"
  rm -f "$sock"
  mpvpaper -p -o "--no-audio --loop-file=inf --hwdec=$WE_HWDEC --gamma=$WE_GAMMA \
--panscan=$WE_PANSCAN --input-ipc-server=$sock --really-quiet $WE_EXTRA_MPV_OPTS" \
    "$out" "$media" >/dev/null 2>&1 &
  echo $! >"$RUNTIME/$out.pid"
  log "started mpvpaper on $out"
}

# --- wedged-decoder sweep ----------------------------------------------------
# Ryoku's backdrop restarts a player on reported errors; our players are
# separate processes, so the equivalent failure is an mpv that stopped
# advancing while unpaused (decoder wedge — the process stays alive, so the
# plain heal never fires). Once per tick the daemon probes time-pos twice per
# instance: identical positions across the probe gap on an unpaused player
# means wedged -> restart the instance from last-media.
sock_prop() { # SOCKET PROPERTY -> value ("" when unavailable)
  printf '%s\n' "{\"command\":[\"get_property\",\"$2\"]}" \
    | socat -t 0.5 - "UNIX-CONNECT:$1" 2>/dev/null \
    | jq -r '.data // empty' 2>/dev/null || true
}

restart_if_stalled() { # OUTPUT
  local out=$1 sock="$RUNTIME/$1.sock" p1 p2 paused
  [[ -S $sock ]] || return 0
  alive "$out" || return 0
  p1=$(sock_prop "$sock" "time-pos")
  sleep 3
  p2=$(sock_prop "$sock" "time-pos")
  # Read `pause` last: a pause toggled mid-probe must count as paused.
  # Empty replies (dead socket, property missing) are left to the plain heal.
  paused=$(sock_prop "$sock" "pause")
  if [[ -n $p1 && -n $p2 && $p1 == "$p2" && $paused != "true" ]]; then
    log "stalled mpv on $out (time-pos frozen at $p1) — restarting"
    kill "$(<"$RUNTIME/$out.pid")" 2>/dev/null || true
    rm -f "$RUNTIME/$out.pid" "$sock"
    sleep 1
    start_instance "$out" "$(cat "$STATE/last-media")"
  fi
  return 0
}

apply_media() { # MEDIA [heal]   heal = only start dead instances
  local media=$1 heal=${2:-} out json
  json=$(jq -cn --arg f "$media" '{command:["loadfile",$f,"replace"]}')
  while read -r out; do
    [[ -n $out ]] || continue
    if alive "$out"; then
      if [[ -z $heal ]]; then ipc_sock "$RUNTIME/$out.sock" "$json"; fi
    else
      start_instance "$out" "$media"
    fi
  done < <(list_outputs)
  # Single source of truth for the watchdog: whatever was applied last — by
  # the daemon's own rotation or by an external `set` — is what gets healed.
  printf '%s\n' "$media" >"$STATE/last-media"
}

cleanup() {
  local p
  for p in "$RUNTIME"/*.pid; do
    [[ -f $p && $p != "$PIDFILE" ]] || continue
    kill "$(<"$p")" 2>/dev/null || true
    rm -f "$p"
  done
  rm -f "$RUNTIME"/*.sock "$PIDFILE"
}

# --- daemon -----------------------------------------------------------------
cmd_daemon() {
  fix_env
  if [[ -f $PIDFILE ]] && kill -0 "$(<"$PIDFILE")" 2>/dev/null; then
    die "already running (pid $(<"$PIDFILE"))"
  fi
  echo $$ >"$PIDFILE"
  trap cleanup EXIT
  trap 'exit 0' TERM INT
  trap 'STEP=1;  SKIP=1' USR1
  trap 'STEP=-1; SKIP=1' USR2

  if [[ $WE_AUTOSTART == 1 ]]; then
    build_playlist
  else
    # Integrated mode: Quickshell's WallpaperService picks what plays. Start
    # as an idle watchdog and forget any stale media from a previous session,
    # so nothing is applied until the first `set` arrives.
    PLAYLIST=()
    rm -f "$STATE/last-media"
  fi

  local idx=0 n current="" media="" elapsed spid step heal_media s out
  while :; do
    n=${#PLAYLIST[@]}
    media=""
    if (( n > 0 )); then
      current=${PLAYLIST[$idx]}
      if media=$(resolve_media "$current"); then
        printf '%s\n' "$current" >"$STATE/current"
        rm -f "$STATE/paused"
        apply_media "$media"
        log "now playing: $current"
      else
        log "skipping unplayable: $current"
        media=""
      fi
    fi

    elapsed=0
    while (( elapsed < WE_INTERVAL && SKIP == 0 )); do
      sleep "$WE_TICK" & spid=$!
      wait "$spid" || true
      kill "$spid" 2>/dev/null || true
      elapsed=$(( elapsed + WE_TICK ))
      # Heal whatever should be on screen — our own pick or an external `set`.
      if [[ -s $STATE/last-media ]]; then
        heal_media=$(cat "$STATE/last-media")
        apply_media "$heal_media" heal
        # Wedged-decoder sweep: a frozen-but-alive mpv gets restarted.
        for s in "$RUNTIME"/*.sock; do
          [[ -S $s ]] || continue
          out=${s##*/}; out=${out%.sock}
          restart_if_stalled "$out"
        done
      fi
    done

    if [[ $WE_AUTOSTART == 1 ]]; then
      step=$STEP; STEP=1; SKIP=0
      idx=$(( idx + step ))
      if (( idx >= n )); then
        build_playlist; idx=0
        if (( ${#PLAYLIST[@]} > 1 )) && [[ ${PLAYLIST[0]} == "$current" ]]; then
          PLAYLIST[0]=${PLAYLIST[1]}; PLAYLIST[1]=$current
        fi
      elif (( idx < 0 )); then
        idx=$(( n - 1 ))
      fi
    else
      STEP=1; SKIP=0   # integrated mode: never self-advance
    fi
  done
}

# --- client commands --------------------------------------------------------
signal_daemon() {
  if [[ ! -f $PIDFILE ]] || ! kill -0 "$(<"$PIDFILE")" 2>/dev/null; then
    die "daemon not running"
  fi
  kill "-$1" "$(<"$PIDFILE")"
}

set_pause() { # VALUE SOCKET
  ipc_sock "$2" "$(jq -cn --argjson v "$1" '{command:["set_property","pause",$v]}')"
}

cmd_pause()  { each_sock set_pause true;  : >"$STATE/paused"; }
cmd_resume() { each_sock set_pause false; rm -f "$STATE/paused"; }
cmd_toggle() { if [[ -f $STATE/paused ]]; then cmd_resume; else cmd_pause; fi; }

cmd_set() {
  local f=${1:-}; [[ -f $f ]] || die "usage: wallpaper-engine set FILE"
  f=$(realpath "$f")
  local media; media=$(resolve_media "$f") || die "cannot play $f"
  apply_media "$media"   # loadfile on live instances + start dead ones
  printf '%s\n' "$f" >"$STATE/current"
}

cmd_clear() { # instances only — the daemon stays up as watchdog
  rm -f "$STATE/last-media" "$STATE/current"
  local p
  for p in "$RUNTIME"/*.pid; do
    [[ -f $p && $p != "$PIDFILE" ]] || continue
    kill "$(<"$p")" 2>/dev/null || true
    rm -f "$p"
  done
  rm -f "$RUNTIME"/*.sock
  log "cleared mpvpaper instances"
}

cmd_status() {
  local running=false paused=false instances=0 p
  if [[ -f $PIDFILE ]] && kill -0 "$(<"$PIDFILE")" 2>/dev/null; then running=true; fi
  if [[ -f $STATE/paused ]]; then paused=true; fi
  for p in "$RUNTIME"/*.pid; do
    [[ -f $p && $p != "$PIDFILE" ]] || continue
    if kill -0 "$(<"$p")" 2>/dev/null; then instances=$(( instances + 1 )); fi
  done
  jq -cn --argjson running "$running" --argjson paused "$paused" \
    --arg current "$(cat "$STATE/current" 2>/dev/null || true)" \
    --argjson interval "$WE_INTERVAL" --argjson instances "$instances" \
    '{running:$running, paused:$paused, current:$current, interval:$interval, instances:$instances}'
}

cmd_list() { build_playlist; printf '%s\n' "${PLAYLIST[@]}"; }

scan_static() { # FILE — OLED burn-in heuristic: flag static stretches
  local f=$1 freezes
  # freezedetect: >99.7% unchanged pixels for 2 s = a freeze event. Baked-in
  # logos/HUDs that never move will trip it at their loop point; fully static
  # clips trip it immediately. First 90 s only — this is a warning scan, not
  # an audit.
  freezes=$(ffmpeg -nostdin -nostats -t 90 -i "$f" \
    -vf "freezedetect=n=0.003:d=2" -an -f null - 2>&1 | grep -c 'freeze_start') || true
  if (( freezes > 0 )); then
    log "WARNING: $f holds static stretch(es) (x$freezes in first 90 s) — burn-in risk on OLED"
  fi
}

cmd_convert() {
  build_playlist
  local f ext out
  for f in "${PLAYLIST[@]}"; do
    ext="${f##*.}"; ext="${ext,,}"
    case $ext in
      gif|webp|apng)
        out=$(convert_to_mp4 "$f") || { log "failed: $f"; continue; }
        ;;
      *)
        out=$f
        ;;
    esac
    scan_static "$out"
  done
  log "conversion done (cache: $CACHE)"
}

cmd_stop() {
  if [[ -f $PIDFILE ]] && kill -0 "$(<"$PIDFILE")" 2>/dev/null; then
    kill -TERM "$(<"$PIDFILE")"
  else
    cleanup
  fi
}

case "${1:-}" in
  daemon)  cmd_daemon ;;
  next)    signal_daemon USR1 ;;
  prev)    signal_daemon USR2 ;;
  pause)   cmd_pause ;;
  resume)  cmd_resume ;;
  toggle)  cmd_toggle ;;
  set)     shift; cmd_set "${1:-}" ;;
  clear)   cmd_clear ;;
  status)  cmd_status ;;
  list)    cmd_list ;;
  convert) cmd_convert ;;
  stop)    cmd_stop ;;
  *) sed -n '2,25p' "$0"; exit 1 ;;
esac
