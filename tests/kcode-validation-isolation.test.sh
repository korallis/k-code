#!/usr/bin/env bash
# Regression coverage for repository-scoped Pi validation isolation.
set -euo pipefail

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CONFIG="$ROOT/.no-mistakes.yaml"

resolved_args() {
  awk '
    /^agent_args_override:/ {in_overrides=1; next}
    in_overrides && /^  pi:/ {in_pi=1; next}
    in_pi && /^    - / {sub(/^    - /, ""); print; next}
    in_pi {exit}
  ' "$CONFIG"
}

test_validation_profile_disables_extensions() {
  local actual expected
  actual=$(resolved_args)
  expected=$(printf '%s\n' --model openai-codex/gpt-5.6-sol --thinking medium --no-extensions)
  [ "$actual" = "$expected" ] \
    || fail "resolved Pi validation arguments changed: $actual"
  pass 'repository validation keeps the intended Pi model and disables extensions'
}

test_print_mode_cannot_load_project_supervision_extensions() {
  local temp project output marker
  if ! command -v pi >/dev/null 2>&1; then
    pass 'project extension isolation is declared; live Pi probe unavailable'
    return 0
  fi
  temp=$(fm_test_tmproot kcode-validation-isolation)
  project="$temp/project"
  marker="$temp/extension-loaded"
  mkdir -p "$project/.pi/extensions" "$temp/pi-home"
  python3 - "$project/.pi/extensions/contaminate.ts" "$marker" <<'PY'
import json
import sys
from pathlib import Path

Path(sys.argv[1]).write_text(
    'import { writeFileSync } from "node:fs";\n'
    f'writeFileSync({json.dumps(sys.argv[2])}, "loaded\\n");\n'
    'console.log("SUPERVISION_PROSE_FROM_PROJECT_EXTENSION");\n',
    encoding="utf-8",
)
PY

  output=$(cd "$project" && PI_CODING_AGENT_DIR="$temp/pi-home" \
    pi --no-extensions --list-models 2>&1)
  [ ! -e "$marker" ] || fail 'Pi loaded a project extension despite --no-extensions'
  assert_not_contains "$output" 'SUPERVISION_PROSE_FROM_PROJECT_EXTENSION' \
    'project extension contaminated non-TUI Pi output'
  pass 'non-TUI Pi validation output cannot activate project extensions'
}

test_validation_profile_disables_extensions
test_print_mode_cannot_load_project_supervision_extensions
