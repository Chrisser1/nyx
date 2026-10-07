# Fake curl for nyx-lyrics: logs the call to $STUB_DIR/curl.log and answers from
# $STUB_DIR/get.json or search.json, failing like `curl -f` when the file is absent.
echo "$*" >> "$STUB_DIR/curl.log"
for arg in "$@"; do
  case $arg in
    */api/get) file=get.json ;;
    */api/search) file=search.json ;;
  esac
done
[ -f "$STUB_DIR/${file:-}" ] || { echo "curl: (22) The requested URL returned error: 404" >&2; exit 22; }
cat "$STUB_DIR/$file"
