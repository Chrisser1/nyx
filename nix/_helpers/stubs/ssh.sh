# Fake ssh: `-G <alias>` prints the hostname listed for it in $STUB_DIR/hosts
# ("alias host" per line). A probe (`... <login> true`) succeeds for the logins
# in $STUB_DIR/allowed and is refused otherwise; any other call is logged.
if [ "$1" = -G ]; then
  while read -r name host; do
    if [ "$name" = "$2" ]; then echo "hostname $host"; exit 0; fi
  done < "$STUB_DIR/hosts"
  echo "hostname $2"
  exit 0
fi
if [ "${*: -1}" = true ]; then
  while read -r allowed; do
    [ "$allowed" = "${*: -2:1}" ] && exit 0
  done < "$STUB_DIR/allowed"
  echo "tailscale: tailnet policy does not permit you to SSH as user \"$(l=${*: -2:1}; echo "${l%%@*}")\"" >&2
  exit 255
fi
echo "ssh $*" >> "$STUB_DIR/calls"
