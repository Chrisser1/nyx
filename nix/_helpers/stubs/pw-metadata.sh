# Fake pw-metadata: logs its arguments to $STUB_DIR/metadata.
echo "$*" >> "$STUB_DIR/metadata"
