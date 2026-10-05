# Bitwarden through rbw. Secrets are copied as sensitive, so clipboard history
# skips them, and cleared after NYX_BITWARDEN_CLEAR seconds (0 keeps them).
usage() {
  echo "usage: nyx-bitwarden {list|setup <email> <com|eu|url>|unlock|lock|sync|copy <id> password|username|totp|notes}" >&2
  exit 2
}

notify() { notify-send -a nyx -i dialog-password "Bitwarden" "$1" || true; }

case "${1:-}" in
  list)
    # The state decides what the launcher offers; listing never prompts.
    # rbw has no logged-in check, but an unlocked agent or a vault file named
    # after the email means login happened.
    email=$(rbw config show 2>/dev/null | jq -r '.email // empty') || email=
    if [ -z "$email" ]; then
      echo '{"state":"unconfigured","entries":[]}'
    elif rbw unlocked > /dev/null 2>&1; then
      rbw list --raw | jq -c '{state: "unlocked", entries: map({
        id,
        name: (.name // ""),
        user: (.user // ""),
        folder: (.folder // ""),
        type: (.type // ""),
        uri: ((.uris // [])[0] // "")
      })}'
    elif find "${XDG_DATA_HOME:-$HOME/.local/share}/rbw" -maxdepth 1 -name "*$email*" 2>/dev/null | grep -q .; then
      echo '{"state":"locked","entries":[]}'
    else
      echo '{"state":"login","entries":[]}'
    fi ;;
  setup)
    # Configures rbw and logs in. Passwords and 2FA codes come from pinentry,
    # so nothing here needs a terminal. The region is com, eu or a server URL.
    [ $# -eq 3 ] || usage
    email=$2
    case "$3" in
      com) rbw config unset base_url; rbw config unset identity_url ;;
      eu) rbw config set base_url https://api.bitwarden.eu
          rbw config set identity_url https://identity.bitwarden.eu ;;
      http*) rbw config set base_url "$3"; rbw config unset identity_url ;;
      *) usage ;;
    esac
    rbw config set email "$email"
    rbw config set pinentry "$NYX_BITWARDEN_PINENTRY"
    # A failed login leaves the old session untouched, so say why it failed.
    if ! err=$(rbw login 2>&1); then
      notify "Login failed: $(printf '%s' "$err" | tail -n 1)"
      exit 1
    fi
    # Login may leave the vault locked.
    rbw unlocked > /dev/null 2>&1 || rbw unlock
    rbw sync ;;
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
