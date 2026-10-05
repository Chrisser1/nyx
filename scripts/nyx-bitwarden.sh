# Bitwarden through rbw. Secrets are copied as sensitive, so clipboard history
# skips them, and cleared after NYX_BITWARDEN_CLEAR seconds (0 keeps them).
usage() {
  echo "usage: nyx-bitwarden {list|unlock|lock|sync|copy <id> password|username|totp|notes}" >&2
  exit 2
}

notify() { notify-send -a nyx -i dialog-password "Bitwarden" "$1" || true; }

case "${1:-}" in
  list)
    # The state decides what the launcher offers; listing never prompts.
    # rbw has no logged-in check, but login leaves a vault file named after the email.
    email=$(rbw config show 2>/dev/null | jq -r '.email // empty') || email=
    if [ -z "$email" ]; then
      echo '{"state":"unconfigured","entries":[]}'
    elif ! find "${XDG_DATA_HOME:-$HOME/.local/share}/rbw" -maxdepth 1 -name "*$email*" 2>/dev/null | grep -q .; then
      echo '{"state":"login","entries":[]}'
    elif ! rbw unlocked > /dev/null 2>&1; then
      echo '{"state":"locked","entries":[]}'
    else
      rbw list --raw | jq -c '{state: "unlocked", entries: map({
        id,
        name: (.name // ""),
        user: (.user // ""),
        folder: (.folder // ""),
        type: (.type // ""),
        uri: ((.uris // [])[0] // "")
      })}'
    fi ;;
  unlock|lock|sync) rbw "$1" ;;
  copy)
    [ $# -ge 3 ] || usage
    case "$3" in
      password) secret=$(rbw get "$2") ;;
      username|notes) secret=$(rbw get --field "$3" "$2") ;;
      totp) secret=$(rbw code "$2") ;;
      *) usage ;;
    esac || { notify "Could not read the $3"; exit 1; }
    [ -n "$secret" ] || { notify "This entry has no $3"; exit 1; }
    printf '%s' "$secret" | wl-copy --sensitive
    if [ "$NYX_BITWARDEN_CLEAR" -gt 0 ]; then
      # Detached, so callers do not wait; only clears if still ours.
      (
        sleep "$NYX_BITWARDEN_CLEAR"
        [ "$(wl-paste --no-newline 2>/dev/null)" != "$secret" ] || wl-copy --clear
      ) < /dev/null > /dev/null 2>&1 &
    fi ;;
  *) usage ;;
esac
