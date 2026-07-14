#!/usr/bin/env bash
# Regression coverage for tracked-text-only integrity scanning.
set -euo pipefail

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

build_fixture() {
  local repo=$1
  mkdir -p "$repo/bin" "$repo/private"
  cp "$ROOT/bin/kcode-integrity.sh" "$repo/bin/kcode-integrity.sh"
  chmod +x "$repo/bin/kcode-integrity.sh"
  printf 'private/\n' > "$repo/.gitignore"
  printf 'ordinary tracked text\n' > "$repo/tracked.txt"
  git -C "$repo" init -q
  git -C "$repo" add .gitignore bin/kcode-integrity.sh tracked.txt
}

secret_value() {
  printf 'ghp_%036d' 0
}

pairing_value() {
  printf 'FMX_PAIRING_TOKEN=%024d' 0
}

test_scan_ignores_untracked_private_and_tracked_binary_files() {
  local temp repo secret pairing subject field value out
  temp=$(fm_test_tmproot kcode-integrity-private)
  repo="$temp/repo"
  build_fixture "$repo"
  secret=$(secret_value)
  pairing=$(pairing_value)
  subject=patient
  field=id
  value="member""12345"
  printf '%s\n%s %s: %s\n%s\n' "$secret" "$subject" "$field" "$value" "$pairing" \
    > "$repo/private/runtime.log"
  printf '\0%s\n' "$secret" > "$repo/binary.dat"
  git -C "$repo" add -f binary.dat

  out=$("$repo/bin/kcode-integrity.sh" --content-scan-only 2>&1) \
    || fail "scanner rejected ignored private or tracked binary data: $out"
  [ -z "$out" ] || fail "clean content scan emitted diagnostics: $out"
  pass 'content scan reads only tracked regular text files'
}

test_scan_rejects_secret_present_only_in_index() {
  local temp repo secret out rc
  temp=$(fm_test_tmproot kcode-integrity-index)
  repo="$temp/repo"
  build_fixture "$repo"
  secret=$(secret_value)
  printf '%s\n' "$secret" > "$repo/tracked.txt"
  git -C "$repo" add tracked.txt
  printf 'clean working tree replacement\n' > "$repo/tracked.txt"

  rc=0
  out=$("$repo/bin/kcode-integrity.sh" --content-scan-only 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'scanner accepted a secret present only in the staged snapshot'
  assert_contains "$out" 'tracked.txt' 'index-only finding omitted the tracked path'
  assert_not_contains "$out" "$secret" 'index-only finding disclosed secret content'
  pass 'content scan reads indexed blobs instead of working-tree replacements'
}

test_scan_rejects_generated_data_classes_and_keeps_safe_memory() {
  local temp repo out rc
  temp=$(fm_test_tmproot kcode-integrity-data-policy)
  repo="$temp/repo"
  build_fixture "$repo"
  mkdir -p "$repo/data/random-task/screenshots" "$repo/data/another-task"
  printf 'safe durable task memory\n' > "$repo/data/random-task/report.md"
  printf 'generated image\n' > "$repo/data/random-task/screenshots/frame.png"
  printf 'archived history\n' > "$repo/data/another-task/history.bundle"
  git -C "$repo" add -f data

  rc=0
  out=$("$repo/bin/kcode-integrity.sh" --content-scan-only 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'integrity accepted generated data artifacts'
  assert_contains "$out" 'data/random-task/screenshots/frame.png' \
    'integrity did not reject a generated screenshot by content class'
  assert_contains "$out" 'data/another-task/history.bundle' \
    'integrity did not reject an archived Git bundle by content class'
  assert_not_contains "$out" 'data/random-task/report.md' \
    'integrity rejected safe durable text memory'
  assert_not_contains "$(grep -n 'kcode-rebuild-g7' "$repo/bin/kcode-integrity.sh" || true)" \
    'kcode-rebuild-g7' 'integrity special-cases an obsolete task id'
  pass 'integrity excludes generated data classes without task-specific policy'
}

test_scan_reports_paths_and_patterns_without_match_content() {
  local temp repo secret pairing subject field value finding out rc
  temp=$(fm_test_tmproot kcode-integrity-diagnostics)
  repo="$temp/repo"
  build_fixture "$repo"
  secret=$(secret_value)
  pairing=$(pairing_value)
  subject=patient
  field=id
  value="member""12345"
  finding="$repo/tracked finding.txt"
  printf '%s\n%s %s: %s\n%s\n' "$secret" "$subject" "$field" "$value" "$pairing" > "$finding"
  git -C "$repo" add "tracked finding.txt"

  rc=0
  out=$("$repo/bin/kcode-integrity.sh" --content-scan-only 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'scanner accepted tracked secret and PHI patterns'
  assert_contains "$out" 'tracked\ finding.txt' 'diagnostics omitted the matched tracked path'
  assert_contains "$out" 'ghp_[A-Za-z0-9]{36,}' 'diagnostics omitted the secret pattern'
  assert_contains "$out" '(patient|member)' 'diagnostics omitted the PHI pattern'
  assert_contains "$out" 'FMX_PAIRING_TOKEN=[A-Za-z0-9_-]{20,}' \
    'diagnostics omitted the FMX token pattern'
  assert_not_contains "$out" "$secret" 'diagnostics disclosed matched secret content'
  assert_not_contains "$out" 'member12345' 'diagnostics disclosed matched PHI content'
  assert_not_contains "$out" "$pairing" 'diagnostics disclosed matched pairing-token content'
  pass 'content scan reports only matched paths and pattern diagnostics'
}

test_scan_ignores_untracked_private_and_tracked_binary_files
test_scan_rejects_secret_present_only_in_index
test_scan_rejects_generated_data_classes_and_keeps_safe_memory
test_scan_reports_paths_and_patterns_without_match_content
