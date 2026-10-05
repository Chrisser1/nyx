# Fake Evolution: logs how it was started and creates the calendar like a sign-in would.
echo "evolution $*" >> "$STUB_DIR/calls"
rm -f "$STUB_DIR/no-calendar"
