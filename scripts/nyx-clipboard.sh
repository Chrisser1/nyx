# Clipboard history on top of cliphist, plus arrival times and pins, which
# cliphist does not track. History ids are cliphist's; pin ids are "p<hash>".
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/nyx/clipboard"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/nyx/clipboard"
SEEN="$STATE/seen.tsv"
PINS="$STATE/pins"
mkdir -p "$PINS" "$CACHE"
touch "$SEEN"

usage() {
  echo "usage: nyx-clipboard {store|list|text <id>|image <id>|copy <id>|delete <id>|pin <id>|unpin <id>|wipe}" >&2
  exit 2
}

need_id() { [ "$1" -ge 2 ] || usage; }

is_pin() { [[ $1 == p* ]]; }

pin_file() {
  [[ $1 =~ ^p[0-9a-f]{16}$ ]] || { echo "nyx-clipboard: bad pin id $1" >&2; exit 1; }
  [ -f "$PINS/${1#p}.data" ] || { echo "nyx-clipboard: no pin $1" >&2; exit 1; }
  echo "$PINS/${1#p}.data"
}

decode() {
  if is_pin "$1"; then
    cat "$(pin_file "$1")"
  else
    [[ $1 =~ ^[0-9]+$ ]] || { echo "nyx-clipboard: bad id $1" >&2; exit 1; }
    printf '%s\t\n' "$1" | cliphist decode
  fi
}

# key, mtime, preview; one line per pin.
pins() {
  local f key
  for f in "$PINS"/*.data; do
    [ -e "$f" ] || continue
    key=$(basename "$f" .data)
    printf 'p%s\t%s\t%s\n' "$key" "$(stat -c %Y "$f")" "$(cat "$PINS/$key.preview")"
  done
}

# Drops times and cached images of entries that are gone.
prune() {
  local ids=$1 f
  awk -F '\t' 'NR == FNR { keep[$1]; next } $1 in keep' <(printf '%s\n' "$ids") "$SEEN" > "$SEEN.tmp"
  mv "$SEEN.tmp" "$SEEN"
  for f in "$CACHE"/*; do
    [ -e "$f" ] || continue
    grep -qxF "$(basename "$f")" <(printf '%s\n' "$ids") || rm -f "$f"
  done
}

case "${1:-}" in
  store)
    cliphist -max-items "$NYX_CLIPBOARD_MAX_ITEMS" store
    # sed reads to the end: an early exit would SIGPIPE cliphist under pipefail.
    id=$(cliphist list | sed -n '1s/\t.*//p')
    if [ -n "$id" ] && ! awk -F '\t' -v id="$id" '$1 == id { found = 1 } END { exit !found }' "$SEEN"; then
      printf '%s\t%s\n' "$id" "$(date +%s)" >> "$SEEN"
    fi ;;

  list)
    # cliphist errors until its database exists.
    history=$(cliphist list 2>/dev/null || true)
    pinned=$(pins)
    prune "$(printf '%s\n%s\n' "$history" "$pinned" | cut -f 1)"
    jq -n --arg history "$history" --arg pins "$pinned" --rawfile seen "$SEEN" '
      def rows: split("\n") | map(select(length > 0) | split("\t"));
      def entry($id; $preview; $time; $pinned):
        ([$preview | capture("^\\[\\[ binary data (?<size>.+) (?<format>[a-z0-9]+) (?<width>[0-9]+)x(?<height>[0-9]+) \\]\\]$")] | .[0]) as $img
        | { id: $id, pinned: $pinned, time: $time, preview: $preview }
          + if $img then
              { kind: "image", size: $img.size, format: $img.format,
                width: ($img.width | tonumber), height: ($img.height | tonumber) }
            else { kind: "text" } end;
      ($seen | rows | map({ (.[0]): (.[1] | tonumber) }) | add // {}) as $times
      | [($pins | rows[] | entry(.[0]; .[2:] | join("\t"); .[1] | tonumber; true)),
         ($history | rows[] | entry(.[0]; .[1:] | join("\t"); $times[.[0]]; false))]' ;;

  text)
    need_id $#
    decode "$2" ;;

  image)
    need_id $#
    out="$CACHE/$2"
    if [ ! -s "$out" ]; then
      decode "$2" > "$out.tmp"
      mv "$out.tmp" "$out"
    fi
    echo "$out" ;;

  copy)
    need_id $#
    decode "$2" | wl-copy ;;

  delete)
    need_id $#
    if is_pin "$2"; then
      file=$(pin_file "$2")
      rm -f "$file" "${file%.data}.preview"
    else
      decode "$2" > /dev/null
      printf '%s\t\n' "$2" | cliphist delete
    fi
    rm -f "$CACHE/$2" ;;

  pin)
    # Moves the entry out of history so it survives wipes and eviction.
    need_id $#
    if is_pin "$2"; then exit 0; fi
    preview=$(cliphist list | awk -F '\t' -v id="$2" '$1 == id { sub(/^[^\t]*\t/, ""); print }')
    [ -n "$preview" ] || { echo "nyx-clipboard: no entry $2" >&2; exit 1; }
    decode "$2" > "$PINS/new.data"
    key=$(sha256sum "$PINS/new.data" | cut -c 1-16)
    mv "$PINS/new.data" "$PINS/$key.data"
    printf '%s' "$preview" > "$PINS/$key.preview"
    printf '%s\t\n' "$2" | cliphist delete
    rm -f "$CACHE/$2"
    echo "p$key" ;;

  unpin)
    # Back into history as the newest entry, so nothing is lost.
    need_id $#
    file=$(pin_file "$2")
    "$0" store < "$file"
    rm -f "$file" "${file%.data}.preview" "$CACHE/$2" ;;

  wipe)
    # Pins are kept.
    cliphist wipe
    : > "$SEEN"
    find "$CACHE" -mindepth 1 -delete ;;

  *) usage ;;
esac
