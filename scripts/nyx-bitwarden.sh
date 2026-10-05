# Bitwarden through rbw. Secrets are copied as sensitive, so clipboard history
# skips them, and cleared after NYX_BITWARDEN_CLEAR seconds (0 keeps them).
usage() {
  echo "usage: nyx-bitwarden {list|setup <email> <com|eu|url>|unlock|lock|sync|copy <id> password|username|totp|notes [label]|type <id> password|username|totp}" >&2
  exit 2
}

VAULT_COPY="${XDG_STATE_HOME:-$HOME/.local/state}/nyx/clipboard/vault"

notify() { notify-send -a nyx -i dialog-password "Bitwarden" "$1" || true; }

# Prints one field of an entry, or tells the user why it cannot.
read_secret() {
  local secret
  case "$2" in
    password) secret=$(rbw get "$1") ;;
    username|notes) secret=$(rbw get --field "$2" "$1") ;;
    totp) secret=$(rbw code "$1") ;;
    *) usage ;;
  esac || { notify "Could not read the $2"; return 1; }
  [ -n "$secret" ] || { notify "This entry has no $2"; return 1; }
  printf '%s' "$secret"
}

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
    # Bitwarden refuses a device it has not seen and rbw cannot take the emailed
    # code, so register it with the account's API key instead. Only the agent
    # log says so, hence reading what the attempt appended to it.
    log="${XDG_DATA_HOME:-$HOME/.local/share}/rbw/agent.err"
    seen=$(wc -l < "$log" 2>/dev/null || echo 0)
    if ! err=$(rbw login 2>&1); then
      if tail -n +"$((seen + 1))" "$log" 2>/dev/null | grep -q "New device verification required"; then
        notify "New device: enter your API key (vault: Settings, Security, Keys, View API key)"
        if ! err=$(rbw register 2>&1); then
          notify "Register failed: $(printf '%s' "$err" | tail -n 1)"
          exit 1
        fi
        err=$(rbw login 2>&1) || { notify "Login failed: $(printf '%s' "$err" | tail -n 1)"; exit 1; }
      else
        notify "Login failed: $(printf '%s' "$err" | tail -n 1)"
        exit 1
      fi
    fi
    # Login may leave the vault locked.
    rbw unlocked > /dev/null 2>&1 || rbw unlock
    rbw sync ;;
  unlock|lock|sync) rbw "$1" ;;
  copy)
    [ $# -ge 3 ] || usage
    secret=$(read_secret "$2" "$3") || exit $?
    printf '%s' "$secret" | wl-copy --sensitive
    # The history never holds the secret, only a row saying what was copied.
    mkdir -p "$(dirname "$VAULT_COPY")"
    printf '%s\t%s\t%s\t%s\n' "$(date +%s)" "$2" "$3" "${4:-$2}" > "$VAULT_COPY"
    if [ "$NYX_BITWARDEN_CLEAR" -gt 0 ]; then
      # Detached, so callers do not wait; only clears if still ours.
      (
        sleep "$NYX_BITWARDEN_CLEAR"
        rm -f "$VAULT_COPY"
        [ "$(wl-paste --no-newline 2>/dev/null)" != "$secret" ] || wl-copy --clear
      ) < /dev/null > /dev/null 2>&1 &
    fi ;;
  type)
    # Types a field into the focused window, so it never touches the clipboard.
    # The caller has just closed its panel, so wait for focus to come back.
    [ $# -ge 3 ] || usage
    secret=$(read_secret "$2" "$3") || exit $?
    sleep "$NYX_BITWARDEN_TYPE_DELAY"
    wtype -- "$secret" ;;
  *) usage ;;
esac
