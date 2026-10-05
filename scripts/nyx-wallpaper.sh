# State holds paths relative to the root, so store-path changes can't break it.
ROOT="$NYX_WALLPAPER_DIR"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/nyx"
FILE="$STATE/wallpapers.json"
SOCKDIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/nyx-gslapper"
mkdir -p "$STATE" "$SOCKDIR"
[ -f "$FILE" ] || echo '{}' > "$FILE"

is_video() { case "${1,,}" in *.mp4|*.mkv|*.webm|*.avi|*.mov) return 0 ;; *) return 1 ;; esac; }

list() {
  (cd "$ROOT" && find -L . -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \
       -o -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' \) \
    | sed 's|^\./||' | sort)
}

outputs() { hyprctl -j monitors | jq -r '.[].name'; }

owns_socket() { tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null | grep -qF "nyx-gslapper/$2.sock"; }

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
    --gst-options "$opts" --fps-cap 60 "$out" "$ROOT/$rel" >/dev/null 2>&1 || true
  # --fork detaches; find the child by its socket path.
  for cand in $(pgrep -f gslapper || true); do
    if owns_socket "$cand" "$out"; then echo "$cand" > "$pidfile"; fi
  done
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
  current) jq -r --arg o "${2:-}" '.[$o] // ""' "$FILE" ;;
  state) cat "$FILE" ;;
  set)
    [ $# -ge 3 ] || { echo "usage: nyx-wallpaper set <output> <relative-path>" >&2; exit 2; }
    apply "$2" "$3" && save "$2" "$3" ;;
  set-all)
    [ $# -ge 2 ] || { echo "usage: nyx-wallpaper set-all <relative-path>" >&2; exit 2; }
    for o in $(outputs); do apply "$o" "$2" && save "$o" "$2"; done
    nyx-theme sync "$ROOT/$2" ;;
  restore)
    for o in $(outputs); do
      rel=$(jq -r --arg o "$o" '.[$o] // ""' "$FILE")
      rel=${rel:-$NYX_WALLPAPER_DEFAULT}
      [ -n "$rel" ] || continue
      { apply "$o" "$rel" && save "$o" "$rel"; } || true
    done ;;
  *)
    echo "usage: nyx-wallpaper {list|outputs|current <out>|state|set <out> <rel>|set-all <rel>|restore|root}" >&2
    exit 2 ;;
esac
