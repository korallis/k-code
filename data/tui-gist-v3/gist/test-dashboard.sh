#!/usr/bin/env bash
# Hermetic smoke tests for live-status-dashboard.sh (ONCE mode).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASH="$ROOT/live-status-dashboard.sh"
fail=0
strip() { sed 's/\x1b\[[0-9;?]*[A-Za-z]//g'; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/state"
cp "$DASH" "$ROOT/fake-state.sh" "$work/" 2>/dev/null || true
cp "$DASH" "$work/live-status-dashboard.sh"
cp "$ROOT/fake-state.sh" "$work/fake-state.sh"
chmod +x "$work/live-status-dashboard.sh" "$work/fake-state.sh"

# (a) empty fleet
out="$(ONCE=1 HOME_DIR="$work" "$work/live-status-dashboard.sh" 2>&1 | strip)"
if printf '%s' "$out" | grep -q "no tasks in flight"; then
  echo "PASS (a) empty fleet"
else
  echo "FAIL (a) empty fleet: $out"; fail=1
fi

# (b)+(c) one task
cat > "$work/state/demo-x1.meta" <<'META'
project=/tmp/example-projects/sample-app
harness=grok
kind=ship
META
out="$(ONCE=1 HOME_DIR="$work" STATE_CMD="$work/fake-state.sh" "$work/live-status-dashboard.sh" 2>&1 | strip)"
if printf '%s' "$out" | grep -q "demo-x1" \
   && printf '%s' "$out" | grep -q "sample-app" \
   && printf '%s' "$out" | grep -q "grok" \
   && printf '%s' "$out" | grep -q "validating"; then
  echo "PASS (b) one task rendered"
else
  echo "FAIL (b) one task: $out"; fail=1
fi
if printf '%s' "$out" | grep -q "doing the thing"; then
  echo "PASS (c) state note surfaced"
else
  echo "FAIL (c) note: $out"; fail=1
fi

exit "$fail"
