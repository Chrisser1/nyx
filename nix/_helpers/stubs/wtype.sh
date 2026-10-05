# Fake wtype: the last argument is the text, kept in $STUB_DIR/typed.
printf '%s' "${*: -1}" > "$STUB_DIR/typed"
