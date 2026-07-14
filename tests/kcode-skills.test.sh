#!/usr/bin/env bash
# Regression coverage for k-code's complete skill inventory and offline restore.
set -euo pipefail

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SKILLS="$ROOT/bin/kcode-skills.sh"
RESTORE="$ROOT/skill-snapshot/restore.tsv"
MANAGED="$ROOT/skill-snapshot/harness-managed.tsv"

write_dummy_skill() {
  local root=$1 name=$2
  mkdir -p "$root/$name"
  cat > "$root/$name/SKILL.md" <<EOF_SKILL
---
name: $name
description: Harness-managed fixture for inventory verification.
---

# $name
EOF_SKILL
}

managed_names() {
  local harness=$1 component=$2
  awk -F '\t' -v harness="$harness" -v component="$component" '
    $1 == harness && $2 == component {
      count=split($6, names, ",")
      for (i=1; i<=count; i++) print names[i]
    }
  ' "$MANAGED"
}

test_snapshot_verifies() {
  local out
  out=$($SKILLS verify)
  assert_contains "$out" 'verified 78 restore placements and 458 captured files' \
    'snapshot verification did not cover the complete manifest'
  pass 'captured sources, checksums, frontmatter, and placements verify'
}

test_clean_home_restore() {
  local temp home out
  temp=$(fm_test_tmproot kcode-skills-restore)
  home="$temp/home"
  out=$($SKILLS restore --home "$home")
  assert_contains "$out" 'restored 78 placements' 'restore did not install every captured placement'
  out=$($SKILLS verify-home --home "$home")
  assert_contains "$out" 'verified 78 restored placements' 'restored home did not match captured source'

  assert_present "$home/.agents/skills/no-mistakes/SKILL.md" 'generic no-mistakes skill is missing'
  assert_present "$home/.claude/skills/workflow/SKILL.md" 'captured Vercel skill is missing from Claude'
  assert_present "$home/.codex/skills/threejs-game-director/SKILL.md" 'Three.js skill is missing from Codex'
  assert_present "$home/.grok/skills/bootstrap-ios/SKILL.md" 'shared skill is missing from Grok'
  assert_present "$home/.claude/skills/.threejs-game-skills-managed" 'Claude manager marker is missing'
  assert_present "$home/.codex/skills/.threejs-game-skills-managed" 'Codex manager marker is missing'
  [ -z "$(find "$home" -type l -print -quit)" ] || fail 'restore created a machine-dependent symlink'
  pass 'clean home restores all captured harness placements without absolute links'
}

test_restore_refuses_different_existing_skill() {
  local temp home out rc
  temp=$(fm_test_tmproot kcode-skills-collision)
  home="$temp/home"
  mkdir -p "$home/.agents/skills/no-mistakes"
  printf 'local override\n' > "$home/.agents/skills/no-mistakes/SKILL.md"
  rc=0
  out=$($SKILLS restore --home "$home" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'restore overwrote a different existing skill'
  assert_contains "$out" 'refusing to overwrite different installed skill' \
    'restore collision did not explain its refusal'
  [ "$(cat "$home/.agents/skills/no-mistakes/SKILL.md")" = 'local override' ] \
    || fail 'restore changed the pre-existing skill after refusing it'
  pass 'restore never overwrites a different user skill'
}

test_manifest_covers_every_captured_source_once() {
  local tracked_count vendor_count source_count skill_doc_count restore_count
  tracked_count=$(find "$ROOT/.agents/skills" "$ROOT/skills" -mindepth 2 -maxdepth 2 \
    -type f -name SKILL.md | wc -l | tr -d ' ')
  vendor_count=$(awk -F '\t' '$1 !~ /^#/ {seen[$1]=1} END {for (path in seen) count++; print count+0}' "$RESTORE")
  source_count=$((tracked_count + vendor_count))
  skill_doc_count=$(find "$ROOT/.agents/skills" "$ROOT/skills" "$ROOT/skill-snapshot/vendor" \
    -type f -name SKILL.md | wc -l | tr -d ' ')
  restore_count=$(grep -vc '^#' "$RESTORE")
  [ "$source_count" -eq 58 ] || fail "expected 58 captured top-level skill trees, found $source_count"
  [ "$skill_doc_count" -eq 68 ] || fail "expected 68 complete skill documents, found $skill_doc_count"
  [ "$restore_count" -eq 78 ] || fail "expected 78 restore placements, found $restore_count"
  [ -z "$(find "$ROOT/skill-snapshot/vendor" -type l -print -quit)" ] \
    || fail 'vendored source contains a symlink'
  ! grep -R -n '/Users/leebarry' "$ROOT/skill-snapshot" >/dev/null \
    || fail 'skill snapshot contains an absolute link or source path to the capture machine'
  pass 'manifest counts and path boundaries cover the deduplicated source set'
}

test_live_inventory_detects_unclassified_skill() {
  local temp home plugin_dir name out rc
  temp=$(fm_test_tmproot kcode-skills-live)
  home="$temp/home"
  plugin_dir="$home/plugin-vercel"
  $SKILLS restore --home "$home" >/dev/null

  # The active setup gets Vercel skills from the plugin, not from Claude's direct root.
  awk -F '\t' '$1 ~ /vendor\/vercel-plugin\// {print $3}' "$RESTORE" \
    | while IFS= read -r name; do rm -rf "$home/.claude/skills/$name"; done

  while IFS= read -r name; do
    write_dummy_skill "$home/.codex/skills/.system" "$name"
  done < <(managed_names Codex codex-cli)
  while IFS= read -r name; do
    write_dummy_skill "$home/.grok/skills" "$name"
  done < <(managed_names Grok 'grok user stock skills')
  while IFS= read -r name; do
    write_dummy_skill "$home/.grok/bundled/skills" "$name"
  done < <(managed_names Grok 'grok bundled skills')

  mkdir -p "$plugin_dir/.claude-plugin" "$home/.claude/plugins"
  cp -R "$ROOT/skill-snapshot/vendor/vercel-plugin/skills" "$plugin_dir/skills"
  cp "$ROOT/skill-snapshot/vendor/vercel-plugin/plugin.json" \
    "$plugin_dir/.claude-plugin/plugin.json"
  cat > "$home/.claude/plugins/installed_plugins.json" <<EOF_JSON
{"version":2,"plugins":{"vercel@claude-plugins-official":[{"installPath":"$plugin_dir"}]}}
EOF_JSON

  out=$($SKILLS verify-live --from-home "$ROOT" --user-home "$home")
  assert_contains "$out" 'live roots match the complete captured inventory' \
    'classified live fixture did not verify'

  write_dummy_skill "$home/.grok/skills" unclassified-skill
  rc=0
  out=$($SKILLS verify-live --from-home "$ROOT" --user-home "$home" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'live inventory accepted an unclassified skill'
  assert_contains "$out" 'live inventory mismatch for Grok user skill root' \
    'unclassified-skill failure did not identify the changed root'
  pass 'live inventory blocks new skills instead of silently omitting them'
}

test_snapshot_verifies
test_clean_home_restore
test_restore_refuses_different_existing_skill
test_manifest_covers_every_captured_source_once
test_live_inventory_detects_unclassified_skill
