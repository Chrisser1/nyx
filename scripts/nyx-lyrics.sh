# Lyrics for a track from LRCLIB. Prints {"synced": "<lrc>", "plain": "<text>"},
# or {} when nobody has any. A network failure exits non-zero.
if [ $# -ne 4 ]; then
  echo "usage: nyx-lyrics <artist> <title> <album> <duration-seconds>" >&2
  exit 2
fi
artist=$1 title=$2 album=$3
duration=$(printf '%.0f' "${4:-0}")

api() {
  local path=$1
  shift
  curl -fsS --max-time 10 -H 'User-Agent: nyx-shell' -G "https://lrclib.net/api/$path" "$@"
}

shape='{synced: (.syncedLyrics // ""), plain: (.plainLyrics // "")}'
args=(--data-urlencode "artist_name=$artist" --data-urlencode "track_name=$title")

# An exact match (the album and length disambiguate versions) first, then the
# best search hit: synced ones before plain.
if hit=$(api get "${args[@]}" --data-urlencode "album_name=$album" --data-urlencode "duration=$duration" 2>/dev/null); then
  jq -c "$shape" <<< "$hit"
  exit 0
fi

found=$(api search "${args[@]}")
jq -c "map(select((.syncedLyrics // \"\") != \"\" or (.plainLyrics // \"\") != \"\"))
  | (map(select((.syncedLyrics // \"\") != \"\")) + .)[0] // {} | $shape | if .synced == \"\" and .plain == \"\" then {} else . end" <<< "$found"
