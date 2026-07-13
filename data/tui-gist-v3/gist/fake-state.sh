#!/usr/bin/env bash
# fake-state.sh - demo stand-in for Firstmate's fm-crew-state.sh
# Prints one parseable line: state: WORD · source: LABEL · note
set -u
id="${1:-}"
case "$id" in
  alpha-a1) echo "state: working · source: demo · review (running)" ;;
  beta-b2)  echo "state: parked · source: demo · awaiting_approval" ;;
  demo-x1)  echo "state: validating · source: demo · doing the thing (running)" ;;
  *)        echo "state: unknown · source: demo · no sample for ${id:-?}" ;;
esac
