#!/usr/bin/env bash
# Regression coverage for repository-scoped Pi validation isolation.
set -euo pipefail

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CONFIG="$ROOT/.no-mistakes.yaml"
TURNEND_EXTENSION="$ROOT/.pi/extensions/fm-primary-turnend-guard.ts"
WATCH_EXTENSION="$ROOT/.pi/extensions/fm-primary-pi-watch.ts"
MODE=${1:---static}
[ "$MODE" = --resolver ] || [ "$MODE" = --static ] || fail 'usage: kcode-validation-isolation.test.sh [--static|--resolver]'

stop_isolated_no_mistakes() {
  local run_pid=${1:-} daemon_pid=${2:-}
  if [ -n "$run_pid" ]; then
    kill "$run_pid" 2>/dev/null || true
    wait "$run_pid" 2>/dev/null || true
  fi
  if [ -n "$daemon_pid" ]; then
    kill "$daemon_pid" 2>/dev/null || true
    wait "$daemon_pid" 2>/dev/null || true
  fi
}

test_primary_extensions_ignore_ephemeral_sessions() {
  python3 - "$TURNEND_EXTENSION" "$WATCH_EXTENSION" <<'PY'
import sys
from pathlib import Path

for name in sys.argv[1:]:
    text = Path(name).read_text(encoding="utf-8")
    if 'process.argv.includes("--no-session")' not in text:
        raise SystemExit(f"{name} does not identify ephemeral Pi sessions")
    if "export default function (pi: ExtensionAPI) {\n  if (ephemeralSession) return;" not in text:
        raise SystemExit(f"{name} does not disable primary behavior for ephemeral Pi sessions")
PY
  pass 'primary Pi extensions are inert in ephemeral validation sessions'
}

test_validation_uses_ephemeral_pi_session() {
  local temp home project origin fakebin argv daemon_log push_log daemon_pid run_pid out
  command -v no-mistakes >/dev/null 2>&1 || fail 'no-mistakes is required for validation isolation coverage'
  out=$(NO_MISTAKES_NO_UPDATE_CHECK=1 no-mistakes --version 2>&1)
  assert_contains "$out" 'v1.36.' 'validation isolation must exercise the supported no-mistakes v1.36 resolver'

  temp=$(mktemp -d /tmp/kcv.XXXXXX)
  FM_TEST_CLEANUP_DIRS+=("$temp")
  trap fm_test_cleanup EXIT
  home="$temp/home"
  project="$temp/project"
  origin="$temp/origin.git"
  fakebin=$(fm_fakebin "$temp")
  argv="$temp/pi-argv"
  daemon_log="$temp/daemon.log"
  push_log="$temp/push.log"
  mkdir -p "$home/.no-mistakes" "$project"
  export NM_HOME="$home/.no-mistakes"
  cat > "$home/.no-mistakes/config.yaml" <<EOF_CONFIG
agent: pi
agent_path_override:
  pi: $fakebin/pi
EOF_CONFIG
  cat > "$fakebin/pi" <<EOF_PI
#!/usr/bin/env bash
printf '%q ' "\$@" >> '$argv'
printf '\n' >> '$argv'
printf '%s\n' '{"summary":"captured validation invocation"}'
EOF_PI
  chmod +x "$fakebin/pi"

  fm_git_identity
  git -C "$project" init -q -b main
  cp "$CONFIG" "$project/.no-mistakes.yaml"
  cat >> "$project/.no-mistakes.yaml" <<'EOF_REPO_CONFIG'
agent: pi
EOF_REPO_CONFIG
  printf '%s\n' '# resolver fixture' > "$project/README.md"
  git -C "$project" add .no-mistakes.yaml README.md
  git -C "$project" commit -qm initial
  git clone --quiet --bare "$project" "$origin"
  git -C "$project" remote add origin "file://$origin"
  git -C "$project" push -q -u origin main
  git -C "$project" remote set-head origin main

  HOME="$home" NO_MISTAKES_NO_UPDATE_CHECK=1 \
    no-mistakes daemon run --root "$home/.no-mistakes" >"$daemon_log" 2>&1 &
  daemon_pid=$!
  run_pid=
  trap 'stop_isolated_no_mistakes "${run_pid:-}" "${daemon_pid:-}"; fm_test_cleanup' EXIT
  for _ in $(seq 1 100); do
    HOME="$home" NO_MISTAKES_NO_UPDATE_CHECK=1 no-mistakes daemon status >/dev/null 2>&1 && break
    kill -0 "$daemon_pid" 2>/dev/null || fail "isolated no-mistakes daemon exited: $(cat "$daemon_log")"
    sleep 0.05
  done
  HOME="$home" NO_MISTAKES_NO_UPDATE_CHECK=1 no-mistakes daemon status >/dev/null 2>&1 \
    || fail "isolated no-mistakes daemon did not become ready: $(cat "$daemon_log")"

  out=$(cd "$project" && HOME="$home" NO_MISTAKES_NO_UPDATE_CHECK=1 \
    no-mistakes init 2>&1 < /dev/null) \
    || fail "isolated no-mistakes init failed: $out; $(cat "$daemon_log")"
  git -C "$project" switch -q -c validation-fixture
  printf '%s\n' 'feature' >> "$project/README.md"
  git -C "$project" add README.md
  git -C "$project" commit -qm feature
  (cd "$project" && HOME="$home" KCODE_PI_ARGV="$argv" NO_MISTAKES_NO_UPDATE_CHECK=1 \
    git push no-mistakes HEAD:refs/heads/validation-fixture >"$push_log" 2>&1)
  (cd "$project" && HOME="$home" KCODE_PI_ARGV="$argv" NO_MISTAKES_NO_UPDATE_CHECK=1 \
    no-mistakes axi run --intent 'verify repository-scoped Pi arguments' \
      --skip rebase,test,document,lint,push,pr,ci >>"$push_log" 2>&1) &
  run_pid=$!
  for _ in $(seq 1 400); do
    [ -s "$argv" ] && break
    kill -0 "$daemon_pid" 2>/dev/null || fail "isolated no-mistakes daemon exited: $(cat "$daemon_log")"
    if ! kill -0 "$run_pid" 2>/dev/null; then
      wait "$run_pid" || true
      fail "isolated gate push ended before invoking isolated Pi: $(cat "$argv" 2>/dev/null || true); $(cat "$push_log"); $(cat "$daemon_log")"
    fi
    sleep 0.05
  done
  [ -s "$argv" ] \
    || fail "no-mistakes did not invoke Pi: $(cat "$push_log"); $(cat "$daemon_log")"
  out=$(cat "$argv")
  assert_contains "$out" '--mode json --no-session ' \
    'no-mistakes did not mark its Pi invocation as an ephemeral session'

  stop_isolated_no_mistakes "$run_pid" "$daemon_pid"
  run_pid=
  daemon_pid=
  trap 'fm_test_cleanup || true' EXIT
  pass 'no-mistakes invokes Pi through the extension-inert ephemeral path'
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

test_primary_extensions_ignore_ephemeral_sessions
test_print_mode_cannot_load_project_supervision_extensions
if [ "$MODE" = --resolver ]; then
  test_validation_uses_ephemeral_pi_session
else
  pass 'actual no-mistakes resolver integration reserved for the version-matched pipeline'
fi
