#!/usr/bin/env bash
# live-status-dashboard.sh - portable flicker-free multi-task status TUI
# Pattern matching Firstmate's fm-validation-dashboard (compose + home + clear-to-end; sleep pacing).
#
# Usage:
#   HOME_DIR=./demo-home ./live-status-dashboard.sh [interval-seconds]
#   ONCE=1 HOME_DIR=./demo-home ./live-status-dashboard.sh
#
# Env:
#   HOME_DIR   directory containing state/*.meta  (default: parent of this script)
#   STATE_CMD  executable that prints "state: WORD · source: S · NOTE" for id $1
#              (default: sibling fake-state.sh if present)
#   ONCE=1     single frame then exit
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME_DIR:-$(cd "$SCRIPT_DIR" && pwd)}"
STATE_DIR="$HOME_DIR/state"
INTERVAL="${1:-4}"
STATE_CMD="${STATE_CMD:-$SCRIPT_DIR/fake-state.sh}"

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

status_word_note() { # <id> -> "word\tnote"
  local line word note
  if [ -x "$STATE_CMD" ] || [ -f "$STATE_CMD" ]; then
    line="$("$STATE_CMD" "$1" 2>/dev/null || true)"
  else
    line="state: unknown · source: none · no STATE_CMD"
  fi
  word="$(printf '%s' "$line" | sed -n 's/^state: *\([a-z-]*\).*/\1/p')"
  note="$(printf '%s' "$line" | sed -n 's/.*· \([^·]*\)$/\1/p')"
  [ -z "$word" ] && word="unknown"
  printf '%s\t%s' "$word" "$note"
}

color_for() {
  case "$1" in
    done|passed|merged) printf '%s' "$GN" ;;
    needs-decision|blocked|paused|resolved|parked) printf '%s' "$YE" ;;
    failed|stale) printf '%s' "$RE" ;;
    working|validating) printf '%s' "$CY" ;;
    *) printf '%s' "$R" ;;
  esac
}

compose() {
  local cols now line
  cols="$(term_cols)"
  now="$(date '+%H:%M:%S')"
  pad() { printf '%-*.*s' "$cols" "$cols" "$1"; }

  pad "$(printf '%s  STATUS  ·  live dashboard   %s· refresh %ss · Ctrl-C to quit' "$B$CY" "$DIM" "$INTERVAL")$R"; printf '\n'
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
    [ -z "$crew" ] && crew="-"
    [ -z "$project" ] && project="-"
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
  # Home cursor, paint composed frame, clear to end. Never full-clear each tick.
  { printf '\033[H'; compose; printf '\033[0J'; } 2>/dev/null
}

if [ "${ONCE:-0}" = "1" ]; then compose; exit 0; fi

printf '\033[2J'
tput civis 2>/dev/null || printf '\033[?25l'
while true; do
  render
  sleep "$INTERVAL"
done
