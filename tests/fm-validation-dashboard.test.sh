#!/usr/bin/env bash
# Behavior tests for bin/fm-validation-dashboard.sh - the live validation TUI.
#
# The dashboard renders one frame per refresh from state/*.meta plus a per-task
# fm-crew-state read. These cases pin the render contract in single-frame mode
# (FM_DASH_ONCE=1), hermetically, over a throwaway FM_HOME with a fake
# fm-crew-state so no real fleet is required:
#   (a) empty fleet renders the "(no tasks in flight)" line, no crash
#   (b) one meta renders its id/project/harness and the crew-state word
#   (c) the note tail from fm-crew-state is surfaced
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DASH="$REPO_ROOT/bin/fm-validation-dashboard.sh"
fail=0
strip() { sed 's/\x1b\[[0-9;?]*[A-Za-z]//g'; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/state" "$work/bin"
# Fake fm-crew-state.sh: the dashboard invokes it as a sibling of the real
# script via SCRIPT_DIR, so point FM_HOME at a home whose bin/ has our fake by
# running the real dashboard with a shimmed sibling.
cp "$DASH" "$work/bin/fm-validation-dashboard.sh"
cat > "$work/bin/fm-crew-state.sh" <<'FAKE'
#!/usr/bin/env bash
echo "state: validating · source: run-step · doing the thing (running)"
FAKE
chmod +x "$work/bin/fm-crew-state.sh"

# (a) empty fleet
out="$(FM_DASH_ONCE=1 FM_HOME="$work" "$work/bin/fm-validation-dashboard.sh" 2>&1 | strip)"
if printf '%s' "$out" | grep -q "no tasks in flight"; then
  echo "PASS (a) empty fleet"
else
  echo "FAIL (a) empty fleet: $out"; fail=1
fi

# (b) + (c) one task with project/harness and a crew-state note
cat > "$work/state/demo-x1.meta" <<'META'
window=default:w1:p9
project=/Users/x/projects/k-zero
harness=grok
kind=ship
META
out="$(FM_DASH_ONCE=1 FM_HOME="$work" "$work/bin/fm-validation-dashboard.sh" 2>&1 | strip)"
if printf '%s' "$out" | grep -q "demo-x1" \
   && printf '%s' "$out" | grep -q "k-zero" \
   && printf '%s' "$out" | grep -q "grok" \
   && printf '%s' "$out" | grep -q "validating"; then
  echo "PASS (b) one task rendered"
else
  echo "FAIL (b) one task: $out"; fail=1
fi
if printf '%s' "$out" | grep -q "doing the thing"; then
  echo "PASS (c) crew-state note surfaced"
else
  echo "FAIL (c) note: $out"; fail=1
fi

exit "$fail"
