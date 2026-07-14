#!/usr/bin/env bash
# Behavior tests for deterministic crew-dispatch profile selection.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BASE_PATH=${FM_TEST_BASE_PATH:-/usr/bin:/bin:/usr/sbin:/sbin}
TMP_ROOT=$(fm_test_tmproot fm-dispatch-select-tests)
mkdir -p "$TMP_ROOT"

write_quota() {
  local file=$1 claude_status=$2 claude_five=$3 claude_week=$4 codex_status=$5 codex_five=$6 codex_week=$7
  mkdir -p "$(dirname "$file")"
  cat > "$file" <<JSON
{
  "providers": [
    {
      "provider": "claude",
      "state": { "status": "$claude_status" },
      "windows": [
        { "id": "five_hour", "kind": "session", "percentRemaining": $claude_five },
        { "id": "seven_day", "kind": "weekly", "percentRemaining": $claude_week },
        { "id": "model:fable", "kind": "model", "percentRemaining": 100 }
      ]
    },
    {
      "provider": "codex",
      "state": { "status": "$codex_status" },
      "windows": [
        { "id": "five_hour", "kind": "session", "percentRemaining": $codex_five },
        { "id": "weekly", "kind": "weekly", "percentRemaining": $codex_week },
        { "id": "model:codex_bengalfox:5h", "kind": "model", "percentRemaining": 100 }
      ]
    }
  ]
}
JSON
}

profiles='[{"harness":"claude","model":"claude-sonnet-5","effort":"high"},{"harness":"codex","model":"gpt-5.5","effort":"high"}]'
fanout_rule='{"select":"all","use":[{"harness":"pi","model":"xai-auth/grok-4.5","effort":"high"},{"harness":"pi","model":"openai-codex/gpt-5.6-sol","effort":"high"},{"harness":"pi","model":"claude-bridge/claude-fable-5","effort":"max","quota":{"provider":"claude","window":"model:fable","percentRemainingAbove":0,"fallback":{"harness":"pi","model":"claude-bridge/claude-opus-4-8","effort":"max"}}}]}'
fanout_fable='[{"harness":"pi","model":"xai-auth/grok-4.5","effort":"high"},{"harness":"pi","model":"openai-codex/gpt-5.6-sol","effort":"high"},{"harness":"pi","model":"claude-bridge/claude-fable-5","effort":"max"}]'
fanout_opus='[{"harness":"pi","model":"xai-auth/grok-4.5","effort":"high"},{"harness":"pi","model":"openai-codex/gpt-5.6-sol","effort":"high"},{"harness":"pi","model":"claude-bridge/claude-opus-4-8","effort":"max"}]'

write_fable_quota() {
  local file=$1 status=$2 percent=$3
  cat > "$file" <<JSON
{"providers":[{"provider":"claude","state":{"status":"$status"},"windows":[{"id":"model:fable","kind":"model","percentRemaining":$percent}]}]}
JSON
}

test_higher_min_vendor_wins() {
  local quota out
  quota="$TMP_ROOT/higher.json"
  write_quota "$quota" fresh 80 30 fresh 70 60
  out=$("$ROOT/bin/fm-dispatch-select.sh" --select quota-balanced --quota-json "$quota" "$profiles")
  [ "$out" = '{"harness":"codex","model":"gpt-5.5","effort":"high"}' ] \
    || fail "higher-min vendor should win, got: $out"
  pass "quota-balanced picks the candidate with the higher general-window minimum"
}

test_exact_tie_uses_first_profile() {
  local quota out
  quota="$TMP_ROOT/tie.json"
  write_quota "$quota" fresh 90 50 fresh 60 50
  out=$("$ROOT/bin/fm-dispatch-select.sh" --select quota-balanced --quota-json "$quota" "$profiles")
  [ "$out" = '{"harness":"claude","model":"claude-sonnet-5","effort":"high"}' ] \
    || fail "exact tie should pick first profile, got: $out"
  pass "quota-balanced exact tie uses the first ordered profile"
}

test_quota_missing_falls_back_to_first() {
  local fakebin out err status
  fakebin=$(fm_fakebin "$TMP_ROOT/missing")
  out=$(PATH="$fakebin:$BASE_PATH" "$ROOT/bin/fm-dispatch-select.sh" --select quota-balanced "$profiles" 2>"$TMP_ROOT/missing.err")
  status=$?
  err=$(cat "$TMP_ROOT/missing.err")
  expect_code 0 "$status" "missing quota-axi should not fail dispatch"
  [ "$out" = '{"harness":"claude","model":"claude-sonnet-5","effort":"high"}' ] \
    || fail "missing quota-axi should fall back to first, got: $out"
  assert_contains "$err" "quota-axi missing" "missing quota-axi fallback should be logged"
  pass "quota-axi missing falls back to the first profile and logs"
}

test_quota_error_falls_back_to_first() {
  local fakebin out err status
  fakebin=$(fm_fakebin "$TMP_ROOT/error")
  cat > "$fakebin/quota-axi" <<'SH'
#!/usr/bin/env bash
exit 42
SH
  chmod +x "$fakebin/quota-axi"
  out=$(PATH="$fakebin:$BASE_PATH" "$ROOT/bin/fm-dispatch-select.sh" --select quota-balanced "$profiles" 2>"$TMP_ROOT/error.err")
  status=$?
  err=$(cat "$TMP_ROOT/error.err")
  expect_code 0 "$status" "quota-axi error should not fail dispatch"
  [ "$out" = '{"harness":"claude","model":"claude-sonnet-5","effort":"high"}' ] \
    || fail "quota-axi error should fall back to first, got: $out"
  assert_contains "$err" "quota-axi exited 42" "quota-axi error fallback should be logged"
  pass "quota-axi non-zero exit falls back to the first profile and logs"
}

test_bad_quota_json_falls_back_to_first() {
  local quota out err
  quota="$TMP_ROOT/bad.json"
  printf '%s\n' 'not-json' > "$quota"
  out=$("$ROOT/bin/fm-dispatch-select.sh" --select quota-balanced --quota-json "$quota" "$profiles" 2>"$TMP_ROOT/bad.err")
  err=$(cat "$TMP_ROOT/bad.err")
  [ "$out" = '{"harness":"claude","model":"claude-sonnet-5","effort":"high"}' ] \
    || fail "bad quota JSON should fall back to first, got: $out"
  assert_contains "$err" "unparseable JSON" "bad quota JSON fallback should be logged"
  pass "unparseable quota JSON falls back to the first profile and logs"
}

test_stale_with_cache_needs_clear_margin_to_beat_fresh() {
  local quota out
  quota="$TMP_ROOT/stale-margin.json"
  write_quota "$quota" stale 85 70 fresh 65 60
  out=$("$ROOT/bin/fm-dispatch-select.sh" --select quota-balanced --quota-json "$quota" "$profiles")
  [ "$out" = '{"harness":"codex","model":"gpt-5.5","effort":"high"}' ] \
    || fail "fresh vendor should win when stale lead is below margin, got: $out"

  write_quota "$quota" stale 90 85 fresh 65 60
  out=$("$ROOT/bin/fm-dispatch-select.sh" --select quota-balanced --quota-json "$quota" "$profiles")
  [ "$out" = '{"harness":"claude","model":"claude-sonnet-5","effort":"high"}' ] \
    || fail "stale vendor should win when lead clears margin, got: $out"
  pass "stale cached quota is usable only when it clears the documented margin over fresh"
}

test_vendor_absent_or_unusable_falls_back_conservatively() {
  local quota out err
  quota="$TMP_ROOT/absent.json"
  cat > "$quota" <<'JSON'
{
  "providers": [
    {
      "provider": "codex",
      "state": { "status": "fresh" },
      "windows": [
        { "id": "five_hour", "kind": "session", "percentRemaining": 40 },
        { "id": "weekly", "kind": "weekly", "percentRemaining": 50 }
      ]
    }
  ]
}
JSON
  out=$("$ROOT/bin/fm-dispatch-select.sh" --select quota-balanced --quota-json "$quota" "$profiles")
  [ "$out" = '{"harness":"codex","model":"gpt-5.5","effort":"high"}' ] \
    || fail "available candidate should win over absent vendor, got: $out"

  cat > "$quota" <<'JSON'
{ "providers": [] }
JSON
  out=$("$ROOT/bin/fm-dispatch-select.sh" --select quota-balanced --quota-json "$quota" "$profiles" 2>"$TMP_ROOT/none.err")
  err=$(cat "$TMP_ROOT/none.err")
  [ "$out" = '{"harness":"claude","model":"claude-sonnet-5","effort":"high"}' ] \
    || fail "no usable vendors should fall back to first, got: $out"
  assert_contains "$err" "no usable quota windows" "no usable vendor fallback should be logged"
  pass "absent or unusable vendors resolve to an available candidate or the first fallback"
}

test_all_guard_uses_fable_when_fresh_quota_remains() {
  local quota out
  quota="$TMP_ROOT/fable-available.json"
  write_fable_quota "$quota" fresh 1
  out=$("$ROOT/bin/fm-dispatch-select.sh" --quota-json "$quota" "$fanout_rule")
  [ "$out" = "$fanout_fable" ] || fail "fresh positive Fable quota should retain Fable without changing siblings, got: $out"
  pass "all fan-out retains Fable only when its fresh model quota remains"
}

test_all_guard_falls_back_when_fable_is_exhausted() {
  local quota out
  quota="$TMP_ROOT/fable-exhausted.json"
  write_fable_quota "$quota" fresh 0
  out=$("$ROOT/bin/fm-dispatch-select.sh" --quota-json "$quota" "$fanout_rule")
  [ "$out" = "$fanout_opus" ] || fail "exhausted Fable quota should select Opus without changing siblings, got: $out"
  pass "all fan-out selects the declared fallback when Fable quota is exhausted"
}

test_all_guard_falls_back_when_fable_quota_is_missing() {
  local quota out
  quota="$TMP_ROOT/fable-missing.json"
  printf '%s\n' '{"providers":[{"provider":"claude","state":{"status":"fresh"},"windows":[]}]}' > "$quota"
  out=$("$ROOT/bin/fm-dispatch-select.sh" --quota-json "$quota" "$fanout_rule")
  [ "$out" = "$fanout_opus" ] || fail "missing Fable window should select Opus without changing siblings, got: $out"
  pass "all fan-out selects the declared fallback when Fable quota is missing"
}

test_all_guard_falls_back_when_fable_quota_is_stale() {
  local quota out
  quota="$TMP_ROOT/fable-stale.json"
  write_fable_quota "$quota" stale 100
  out=$("$ROOT/bin/fm-dispatch-select.sh" --quota-json "$quota" "$fanout_rule")
  [ "$out" = "$fanout_opus" ] || fail "stale Fable quota should select Opus without changing siblings, got: $out"
  pass "all fan-out selects the declared fallback when Fable quota is stale"
}

test_all_guard_falls_back_when_quota_is_unparseable() {
  local quota out err
  quota="$TMP_ROOT/fable-unparseable.json"
  printf '%s\n' 'not-json' > "$quota"
  out=$("$ROOT/bin/fm-dispatch-select.sh" --quota-json "$quota" "$fanout_rule" 2>"$TMP_ROOT/fable-unparseable.err")
  err=$(cat "$TMP_ROOT/fable-unparseable.err")
  [ "$out" = "$fanout_opus" ] || fail "unparseable quota should select Opus without changing siblings, got: $out"
  assert_contains "$err" "unparseable JSON" "unparseable all-fan-out quota fallback should be logged"
  pass "all fan-out selects the declared fallback when quota is unparseable"
}

test_backward_compatible_first_selection() {
  local fakebin marker out single array_rule
  fakebin=$(fm_fakebin "$TMP_ROOT/no-call")
  marker="$TMP_ROOT/quota-called"
  cat > "$fakebin/quota-axi" <<SH
#!/usr/bin/env bash
printf called > '$marker'
exit 1
SH
  chmod +x "$fakebin/quota-axi"

  single='{"harness":"grok","model":"grok-4","effort":"high"}'
  out=$(PATH="$fakebin:$BASE_PATH" "$ROOT/bin/fm-dispatch-select.sh" "$single")
  [ "$out" = '{"harness":"grok","model":"grok-4","effort":"high"}' ] \
    || fail "single-object use should resolve to itself, got: $out"

  array_rule='{"when":"big work","use":[{"harness":"claude","effort":"high"},{"harness":"codex","effort":"high"}]}'
  out=$(PATH="$fakebin:$BASE_PATH" "$ROOT/bin/fm-dispatch-select.sh" "$array_rule")
  [ "$out" = '{"harness":"claude","effort":"high"}' ] \
    || fail "array without select should resolve to first, got: $out"
  [ ! -e "$marker" ] || fail "quota-axi should not be called without quota-balanced select"
  pass "single-object use and no-select arrays preserve first-profile selection"
}

test_higher_min_vendor_wins
test_exact_tie_uses_first_profile
test_quota_missing_falls_back_to_first
test_quota_error_falls_back_to_first
test_bad_quota_json_falls_back_to_first
test_stale_with_cache_needs_clear_margin_to_beat_fresh
test_vendor_absent_or_unusable_falls_back_conservatively
test_all_guard_uses_fable_when_fresh_quota_remains
test_all_guard_falls_back_when_fable_is_exhausted
test_all_guard_falls_back_when_fable_quota_is_missing
test_all_guard_falls_back_when_fable_quota_is_stale
test_all_guard_falls_back_when_quota_is_unparseable
test_backward_compatible_first_selection

echo "# all fm-dispatch-select tests passed"
