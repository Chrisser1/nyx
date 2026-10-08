# State holds paths relative to the root, so store-path changes can't break it.
ROOT="$NYX_WALLPAPER_DIR"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/nyx"
FILE="$STATE/wallpapers.json"
THUMBS="${XDG_CACHE_HOME:-$HOME/.cache}/nyx/wallpapers"
SOCKDIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/nyx-gslapper"
mkdir -p "$STATE" "$SOCKDIR" "$THUMBS"
[ -f "$FILE" ] || echo '{}' > "$FILE"

is_video() { case "${1,,}" in *.mp4|*.mkv|*.webm|*.avi|*.mov) return 0 ;; *) return 1 ;; esac; }

list() {
  (cd "$ROOT" && find -L . -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \
       -o -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' \) \
    | sed 's|^\./||' | sort)
}

# Cached thumbnail for a wallpaper: a frame for videos, a downscale for stills.
thumb() {
  local rel=$1 abs="$ROOT/$1" out
  # The size is part of the key so a new size regenerates.
  out="$THUMBS/$(printf '%s@h480' "$abs" | sha1sum | cut -c 1-16).jpg"
  if [ ! -s "$out" ]; then
    if is_video "$rel"; then set -- -ss 1 -i "$abs"; else set -- -i "$abs"; fi
    if ffmpeg -nostdin -loglevel error -y "$@" -frames:v 1 -vf "scale=-2:480" -q:v 4 "$out.tmp.jpg"; then
      mv "$out.tmp.jpg" "$out"
    else
      rm -f "$out.tmp.jpg"
    fi
  fi
  # An empty thumbnail means it could not be made.
  if [ -s "$out" ]; then printf '%s\t%s\n' "$rel" "$out"; else printf '%s\t\n' "$rel"; fi
}

outputs() { hyprctl -j monitors | jq -r '.[].name'; }

# A missing socket (still wallpaper, or none) is not an error.
ipc() { printf '%s\n' "$2" | socat -t 0.2 - "UNIX-CONNECT:$SOCKDIR/$1.sock" > /dev/null 2>&1 || true; }

owns_socket() { [[ "$(tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null)" == *"nyx-gslapper/$2.sock"* ]]; }

apply() {
  local out=$1 rel=$2 pidfile oldpid opts cand
  if [ ! -f "$ROOT/$rel" ]; then
    echo "nyx-wallpaper: missing $rel under $ROOT" >&2
    return 1
  fi
  # Kill by recorded pid; `pkill -f` would match unrelated command lines.
  pidfile="$SOCKDIR/$out.pid"
  if [ -f "$pidfile" ]; then
    oldpid=$(cat "$pidfile")
    if [ -n "$oldpid" ] && owns_socket "$oldpid" "$out"; then kill "$oldpid" || true; fi
    rm -f "$pidfile"
  fi
  if is_video "$rel"; then opts="fill no-audio loop"; else opts="fill"; fi
  gslapper --fork --no-save-state --ipc-socket "$SOCKDIR/$out.sock" \
    --gst-options "$opts" --fps-cap 30 "$out" "$ROOT/$rel" >/dev/null 2>&1 || true
  # --fork detaches; find the child by its socket path.
  for cand in $(pgrep -f gslapper || true); do
    if owns_socket "$cand" "$out"; then echo "$cand" > "$pidfile"; fi
  done
  # The shell hid this output before the new player existed; keep it paused.
  if [ -e "$SOCKDIR/$out.paused" ]; then
    for _ in $(seq 20); do [ -S "$SOCKDIR/$out.sock" ] && break; sleep 0.1; done
    ipc "$out" pause
  fi
}

save() {
  local tmp
  tmp=$(mktemp)
  jq --arg o "$1" --arg p "$2" '.[$o] = $p' "$FILE" > "$tmp" && mv "$tmp" "$FILE"
}

case "${1:-}" in
  root) echo "$ROOT" ;;
  list) list ;;
  outputs) outputs ;;
  thumbs)
    # One line per wallpaper: relative path, thumbnail. Four at a time.
    while IFS= read -r rel; do
      while [ "$(jobs -rp | wc -l)" -ge 4 ]; do wait -n; done
      thumb "$rel" &
    done < <(list)
    wait ;;
  theme)
    # Theme from the wallpaper on the first output.
    rel=$(jq -r --arg o "$(outputs | sed -n 1p)" '.[$o] // ""' "$FILE")
    [ -n "$rel" ] || { echo "nyx-wallpaper: no wallpaper set" >&2; exit 1; }
    nyx-theme wallpaper "$ROOT/$rel" ;;
  current) jq -r --arg o "${2:-}" '.[$o] // ""' "$FILE" ;;
  state) cat "$FILE" ;;
  set)
    [ $# -ge 3 ] || { echo "usage: nyx-wallpaper set <output> <relative-path>" >&2; exit 2; }
    apply "$2" "$3" && save "$2" "$3" ;;
  set-all)
    [ $# -ge 2 ] || { echo "usage: nyx-wallpaper set-all <relative-path>" >&2; exit 2; }
    for o in $(outputs); do apply "$o" "$2" && save "$o" "$2"; done
    nyx-theme sync "$ROOT/$2" ;;
  pause|resume)
    [ $# -eq 2 ] || { echo "usage: nyx-wallpaper $1 <output|all>" >&2; exit 2; }
    if [ "$2" = all ]; then targets=$(outputs); else targets=$2; fi
    for o in $targets; do
      if [ "$1" = pause ]; then touch "$SOCKDIR/$o.paused"; else rm -f "$SOCKDIR/$o.paused"; fi
      ipc "$o" "$1"
    done ;;
  restore)
    for o in $(outputs); do
      rel=$(jq -r --arg o "$o" '.[$o] // ""' "$FILE")
      rel=${rel:-$NYX_WALLPAPER_DEFAULT}
      [ -n "$rel" ] || continue
      { apply "$o" "$rel" && save "$o" "$rel"; } || true
    done ;;
  *)
    echo "usage: nyx-wallpaper {list|thumbs|outputs|current <out>|state|set <out> <rel>|set-all <rel>|pause <out|all>|resume <out|all>|restore|theme|root}" >&2
    exit 2 ;;
esac
