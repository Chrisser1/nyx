# nyx-calendar against the fake backend and Evolution in stubs/.
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

export STUB_DIR=$PWD/stub
mkdir -p "$STUB_DIR"

if nyx-calendar bogus 2>/dev/null; then fail "bogus accepted"; fi
if nyx-calendar add-caldav Home https://x 2>/dev/null; then fail "add-caldav without a user accepted"; fi
if nyx-calendar caldav-config Home https://x 2>/dev/null; then fail "caldav-config without a user accepted"; fi

touch "$STUB_DIR/no-calendar"
if out=$(nyx-calendar events 2026-10-01 2026-10-31); then fail "events succeeded without a calendar"; fi
[ "$out" = '[]' ] || fail "events prints an empty list without a calendar: $out"

# The password travels on stdin, so it never reaches an argument list.
printf 's3cret\n' | nyx-calendar add-caldav Home https://cloud.example.org/dav/ me
[ "$(cat "$STUB_DIR/password")" = s3cret ] || fail "password on stdin"
[ "$(cat "$STUB_DIR/calls")" = "add-caldav Home https://cloud.example.org/dav/ me" ] || fail "arguments: $(cat "$STUB_DIR/calls")"
if grep -q s3cret "$STUB_DIR/calls"; then fail "password leaked into the arguments"; fi
[ "$(nyx-calendar events 2026-10-01 2026-10-31)" = '[]' ] || fail "events after add"

touch "$STUB_DIR/caldav-fails" "$STUB_DIR/no-calendar"
if echo pw | nyx-calendar add-caldav Home https://x/ me 2>/dev/null; then fail "failed add-caldav succeeded"; fi

rm "$STUB_DIR/calls"
nyx-calendar auth
[ "$(cat "$STUB_DIR/calls")" = "evolution -c calendar" ] || fail "auth starts Evolution's calendar"

# Google calendars are listed and added through the backend.
printf '[{"name":"Family","path":"/caldav/v2/x@group.calendar.google.com/events","added":false,"primary":false}]' > "$STUB_DIR/google.json"
[ "$(nyx-calendar google-calendars | jq -r '.[0].name')" = Family ] || fail "google calendars listed"
rm -f "$STUB_DIR/calls"
nyx-calendar add-google /caldav/v2/x@group.calendar.google.com/events Family
nyx-calendar remove-google /caldav/v2/x@group.calendar.google.com/events
[ "$(cat "$STUB_DIR/calls")" = "$(printf 'add-google /caldav/v2/x@group.calendar.google.com/events Family\nremove-google /caldav/v2/x@group.calendar.google.com/events')" ] || fail "google calls: $(cat "$STUB_DIR/calls")"
if nyx-calendar add-google /only/a/path 2>/dev/null; then fail "add-google without a name accepted"; fi

echo "calendar helper tests passed"
