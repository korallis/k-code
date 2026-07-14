#!/usr/bin/env bash
# fm-validation-dashboard.sh - live TUI of every in-flight task and its current
# validation state. Built to dock as a persistent herdr pane so the whole fleet's
# no-mistakes progress is visible at a glance.
#
# Rendering is FLICKER-FREE: each frame is composed into a buffer, then written in
# one pass with a cursor-home + clear-to-end (never a full-screen clear), so rows
# never blank out mid-refresh. State reads are CHEAP (meta + status-log tail only,
# no per-task no-mistakes subprocess), so a frame is near-instant.
#
# Usage: bin/fm-validation-dashboard.sh [<interval-seconds>]
#   Default 4s. Ctrl-C to quit. Honors FM_HOME; self-locates otherwise.
#   FM_DASH_ONCE=1 renders a single frame (tests / non-interactive).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_HOME="${FM_HOME:-$(cd "$SCRIPT_DIR/.." && pwd)}"
STATE_DIR="$FM_HOME/state"
INTERVAL="${1:-4}"

if [ -t 1 ]; then
  R=$'\033[0m'; DIM=$'\033[2m'; B=$'\033[1m'
  CY=$'\033[36m'; GN=$'\033[32m'; YE=$'\033[33m'; RE=$'\033[31m'; GY=$'\033[90m'
else
  R=; DIM=; B=; CY=; GN=; YE=; RE=; GY=
fi

cleanup() { printf '\033[?25h'; tput cnorm 2>/dev/null || true; printf '\n'; exit 0; }
trap cleanup INT TERM

term_cols() { tput cols 2>/dev/null || echo "${COLUMNS:-80}"; }

meta_field() { grep -m1 "^$2=" "$1" 2>/dev/null | cut -d= -f2-; }
CREW_STATE="$SCRIPT_DIR/fm-crew-state.sh"

# ACCURATE current-state via fm-crew-state, which reconciles the authoritative
# no-mistakes run-step over the possibly-stale status log (so "validating" shows
# as validating, not the last "done: committed" event). This is the point of the
# dashboard. It costs a subprocess per task, but double-buffered rendering paints
# the completed frame atomically, so a slower compose never flickers - the prior
# frame simply stays until the new one is ready.
status_word_note() { # <id> -> "word\tnote"
  local line word note
  line="$("$CREW_STATE" "$1" 2>/dev/null)"    # "state: WORD · source: S · NOTE"
  word="$(printf '%s' "$line" | sed -n 's/^state: *\([a-z-]*\).*/\1/p')"
  note="$(printf '%s' "$line" | sed -n 's/.*· \([^·]*\)$/\1/p')"
  [ -z "$word" ] && word="unknown"
  printf '%s\t%s' "$word" "$note"
}

color_for() {
  case "$1" in
    done|passed|merged) printf '%s' "$GN" ;;
    needs-decision|blocked|paused|resolved) printf '%s' "$YE" ;;
    failed|stale) printf '%s' "$RE" ;;
    working) printf '%s' "$CY" ;;
    *) printf '%s' "$R" ;;
  esac
}

# Compose one full frame into stdout. Every line is padded to the terminal width
# so a shorter new line fully overwrites a longer previous one (no leftovers).
compose() {
  local cols now line
  cols="$(term_cols)"
  now="$(date '+%H:%M:%S')"
  pad() { printf '%-*.*s' "$cols" "$cols" "$1"; }

  pad "$(printf '%s  FIRSTMATE  ·  validation dashboard   %s· refresh %ss · Ctrl-C to quit' "$B$CY" "$DIM" "$INTERVAL")$R"; printf '\n'
  pad "$GY$(printf '%*s' "$cols" '' | tr ' ' '-')$R"; printf '\n'
  pad "$(printf '%s%-16s %-15s %-6s %s%s' "$DIM" 'TASK' 'PROJECT' 'CREW' 'STATE' "$R")"; printf '\n'

  shopt -s nullglob; local metas=("$STATE_DIR"/*.meta); shopt -u nullglob
  if [ ${#metas[@]} -eq 0 ]; then
    pad "$DIM  (no tasks in flight)$R"; printf '\n'
    return
  fi

  local m id project crew sw word note col n=0
  for m in "${metas[@]}"; do
    id="$(basename "$m" .meta)"
    project="$(basename "$(meta_field "$m" project)" 2>/dev/null)"
    crew="$(meta_field "$m" harness)"
    sw="$(status_word_note "$id")"
    word="${sw%%$'\t'*}"; note="${sw#*$'\t'}"
    col="$(color_for "$word")"
    line="$(printf '%-16s %-15s %-6s %s%-14s%s %s%s%s' \
      "${id:0:16}" "${project:0:15}" "${crew:0:6}" \
      "$col" "$word" "$R" "$DIM" "${note:0:$((cols>60?cols-55:20))}" "$R")"
    pad "$line"; printf '\n'
    n=$((n + 1))
  done
  pad "$GY$(printf '%*s' "$cols" '' | tr ' ' '-')$R"; printf '\n'
  pad "$DIM  $n task(s) in flight · updated $now$R"; printf '\n'
}

render() {
  # Home cursor, paint the composed frame, then clear from cursor to end of
  # screen. No full clear => no blank flash => no flicker.
  { printf '\033[H'; compose; printf '\033[0J'; } 2>/dev/null
}

if [ "${FM_DASH_ONCE:-0}" = "1" ]; then compose; exit 0; fi

printf '\033[2J'          # one initial clear on entry only
tput civis 2>/dev/null || printf '\033[?25l'
while true; do
  render
  sleep "$INTERVAL"
done
