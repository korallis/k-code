#!/usr/bin/env bash
# fm-dashboard-launch.sh - idempotently auto-spawn the validation dashboard in its
# own herdr tab, the same way firstmate supervises the fleet: created once,
# reused if already present, never stealing focus.
#
# Safe to call every session start. No-op (with a printed reason) when the herdr
# backend is unavailable, so it never breaks a tmux/other-backend session.
#
# Usage: bin/fm-dashboard-launch.sh
#   Honors FM_HOME; self-locates otherwise. Set FM_DASHBOARD_DISABLE=1 to skip.
set -uo pipefail

[ "${FM_DASHBOARD_DISABLE:-0}" = "1" ] && { echo "fm-dashboard: disabled (FM_DASHBOARD_DISABLE=1)"; exit 0; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_HOME="${FM_HOME:-$(cd "$SCRIPT_DIR/.." && pwd)}"
DASH="$SCRIPT_DIR/fm-validation-dashboard.sh"
LABEL="fm-validation"
INTERVAL="${FM_DASHBOARD_INTERVAL:-4}"

command -v herdr >/dev/null 2>&1 || { echo "fm-dashboard: herdr not found; open '$DASH' manually."; exit 0; }
[ "${HERDR_ENV:-0}" = "1" ] || { echo "fm-dashboard: not in a herdr session; open '$DASH' manually."; exit 0; }

# Already registered as an agent? Then it's live in the sidebar - leave it.
if herdr agent list 2>/dev/null | grep -q "$LABEL"; then
  echo "fm-dashboard: already live (agent '$LABEL')."
  exit 0
fi

# Create a DEDICATED tab first, then start the agent into it, so the dashboard
# gets its own tab like each crew (agent start alone lands in the current tab,
# stacking under the captain's main pane). Registers in the left agents sidebar.
tab_id="$(herdr tab create --no-focus --label "$LABEL" --cwd "$FM_HOME" 2>/dev/null \
  | grep -oE '"tab_id":"[^"]*"' | head -1 | cut -d'"' -f4)"
if [ -n "$tab_id" ] && herdr agent start "$LABEL" --no-focus --tab "$tab_id" --cwd "$FM_HOME" \
     -- bash "$DASH" "$INTERVAL" >/dev/null 2>&1; then
  echo "fm-dashboard: started as herdr agent '$LABEL' in its own tab (sidebar)."
  exit 0
fi

# Fallback: a dedicated tab if agent-start is unavailable in this herdr build.
pane_id="$(herdr tab create --no-focus --label "$LABEL" --cwd "$FM_HOME" 2>/dev/null \
  | grep -oE '"pane_id":"[^"]*"' | head -1 | cut -d'"' -f4)"
if [ -z "$pane_id" ]; then
  echo "fm-dashboard: could not spawn dashboard; open '$DASH' manually." >&2
  exit 0
fi
herdr pane rename "$pane_id" "$LABEL" >/dev/null 2>&1 || true
herdr pane send-text "$pane_id" "FM_HOME='$FM_HOME' '$DASH' $INTERVAL" >/dev/null 2>&1
herdr pane send-keys "$pane_id" Enter >/dev/null 2>&1
echo "fm-dashboard: spawned in herdr tab $pane_id (label '$LABEL', fallback)."
