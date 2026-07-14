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

write_pi_package_inventory() {
  local home=$1 component version package_dir
  mkdir -p "$home/.pi/agent"
  cat > "$home/.pi/agent/settings.json" <<'EOF_JSON'
{"packages":["npm:@firstpick/pi-themes-bundle","npm:pi-xai-oauth","npm:pi-claude-bridge"]}
EOF_JSON
  while IFS=$'\t' read -r component version; do
    package_dir="$home/.pi/agent/npm/node_modules/$component"
    mkdir -p "$package_dir"
    printf '{"name":"%s","version":"%s"}\n' "$component" "$version" \
      > "$package_dir/package.json"
  done < <(awk -F '\t' '
    $1 == "Pi" && $2 != "@earendil-works/pi-coding-agent" && $5 ~ /^npm:/ {
      print $2 "\t" $3
    }
  ' "$MANAGED")
}

physical_temp_root() {
  local parent temp
  parent=$(cd "${TMPDIR:-/tmp}" && pwd -P)
  temp=$(mktemp -d "$parent/$1.XXXXXX")
  printf '%s\n' "$temp"
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
  temp=$(physical_temp_root kcode-skills-restore)
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

test_restore_stages_on_destination_filesystem() {
  local temp home hook out
  temp=$(physical_temp_root kcode-skills-exdev)
  home="$temp/home"
  hook="$temp/assert-staging-filesystem"
  mkdir -p "$home"
  cat > "$hook" <<EOF_HOOK
#!/usr/bin/env bash
set -euo pipefail
staging=\$1
[ "\$(dirname "\$staging")" = '$home' ] || {
  echo 'EXDEV regression: staging is outside the existing destination filesystem' >&2
  exit 18
}
python3 - "\$staging" '$home' <<'PY'
import os
import sys

if os.stat(sys.argv[1]).st_dev != os.stat(sys.argv[2]).st_dev:
    raise SystemExit(1)
PY
EOF_HOOK
  chmod +x "$hook"

  out=$(KCODE_RESTORE_TEST_AFTER_STAGING_MKDIR_HOOK="$hook" \
    "$SKILLS" restore --home "$home" 2>&1) \
    || fail "restore did not stage inside the existing destination filesystem: $out"
  "$SKILLS" verify-home --home "$home" >/dev/null
  pass 'existing mounted homes stage and promote without an EXDEV boundary'
}

test_restore_nested_target_mount() {
  local temp home mounted probe probe_target hook runner out
  if [ "$(uname -s)" != Linux ] || ! command -v unshare >/dev/null 2>&1 \
    || ! command -v mount >/dev/null 2>&1 || [ ! -d /dev/shm ] || [ ! -w /dev/shm ]; then
    pass 'nested target-root EXDEV regression # SKIP distinct mount unavailable'
    return
  fi
  temp=$(physical_temp_root kcode-skills-nested-exdev)
  home="$temp/home"
  mounted=$(mktemp -d /dev/shm/kcode-skills-target.XXXXXX)
  probe="$temp/probe"
  probe_target="$temp/probe-target"
  hook="$temp/assert-target-staging"
  runner="$temp/run-mounted-restore"
  mkdir -p "$home/.claude/skills" "$probe_target"
  if python3 - "$home" "$mounted" <<'PY'
import os
import sys

raise SystemExit(os.stat(sys.argv[1]).st_dev == os.stat(sys.argv[2]).st_dev)
PY
  then
    :
  else
    rm -rf "$temp" "$mounted"
    pass 'nested target-root EXDEV regression # SKIP no distinct writable filesystem'
    return
  fi
  cat > "$probe" <<EOF_PROBE
#!/usr/bin/env bash
set -euo pipefail
mount --bind '$mounted' '$probe_target'
umount '$probe_target'
EOF_PROBE
  chmod +x "$probe"
  if ! unshare --user --map-root-user --mount "$probe" >/dev/null 2>&1; then
    rm -rf "$temp" "$mounted"
    pass 'nested target-root EXDEV regression # SKIP mount namespace unavailable'
    return
  fi
  cat > "$hook" <<EOF_HOOK
#!/usr/bin/env bash
set -euo pipefail
case "\$1" in
  '$home/.claude/skills/'*)
    python3 - "\$1" '$home/.claude/skills' '$home' <<'PY'
import os
import sys

staging, target, home = sys.argv[1:]
if os.stat(staging).st_dev != os.stat(target).st_dev:
    raise SystemExit("target staging is not on the destination filesystem")
if os.stat(staging).st_dev == os.stat(home).st_dev:
    raise SystemExit("fixture did not cross a nested filesystem boundary")
PY
    printf 'observed\n' > '$temp/target-staging-observed'
    ;;
esac
EOF_HOOK
  cat > "$runner" <<EOF_RUNNER
#!/usr/bin/env bash
set -euo pipefail
mount --bind '$mounted' '$home/.claude/skills'
KCODE_RESTORE_TEST_AFTER_TARGET_STAGING_MKDIR_HOOK='$hook' \
  '$SKILLS' restore --home '$home' >/dev/null
'$SKILLS' verify-home --home '$home' >/dev/null
EOF_RUNNER
  chmod +x "$hook" "$runner"
  out=$(unshare --user --map-root-user --mount "$runner" 2>&1) \
    || fail "restore failed across a nested target-root mount: $out"
  assert_present "$temp/target-staging-observed" \
    'restore did not stage a payload inside the mounted target root'
  [ -f "$mounted/workflow/SKILL.md" ] \
    || fail 'mounted target root did not receive the restored payload'
  rm -rf "$temp" "$mounted"
  pass 'nested target roots stage and promote on their own filesystem'
}

test_restore_preserves_and_verifies_executable_modes() {
  local temp home executable out rc
  temp=$(physical_temp_root kcode-skills-modes)
  home="$temp/home"
  "$SKILLS" restore --home "$home" >/dev/null
  executable="$home/.claude/skills/bootstrap-ios/scripts/bootstrap-ios-skills.sh"
  [ -x "$executable" ] || fail 'restore dropped a captured executable bit'
  chmod 0644 "$executable"
  rc=0
  out=$("$SKILLS" verify-home --home "$home" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'verify-home accepted executable mode drift'
  assert_contains "$out" 'restored skill differs or is missing' \
    'mode drift failure did not identify the restored skill'
  pass 'restore preserves executable bits and verification rejects mode drift'
}

test_snapshot_rejects_corrupt_provenance() {
  local backup out rc
  backup=$(mktemp "${TMPDIR:-/tmp}/kcode-sources.XXXXXX")
  cp "$ROOT/skill-snapshot/sources.tsv" "$backup"
  cleanup_corrupt_provenance() {
    cp "$backup" "$ROOT/skill-snapshot/sources.tsv"
    rm -f "$backup"
  }
  trap 'cleanup_corrupt_provenance; fm_test_cleanup' EXIT
  python3 - "$ROOT/skill-snapshot/sources.tsv" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
path.write_text(text.replace("ad9f3a71894a96f0af5b9e0fe238acda855d6478", "0000000000000000000000000000000000000000"), encoding="utf-8")
PY
  rc=0
  out=$("$SKILLS" verify 2>&1) || rc=$?
  cleanup_corrupt_provenance
  trap 'fm_test_cleanup || true' EXIT
  [ "$rc" -ne 0 ] || fail 'snapshot verification accepted plausible coordinated provenance corruption'
  assert_contains "$out" 'reviewed provenance digest mismatch: sources.tsv' \
    'authenticated provenance failure was not identified'
  pass 'snapshot verification authenticates reviewed provenance values'
}

test_snapshot_rejects_coordinated_content_corruption() {
  local temp source manifest source_backup manifest_backup out rc
  temp=$(physical_temp_root kcode-skills-content-corruption)
  source="$ROOT/skill-snapshot/vendor/no-mistakes/no-mistakes/SKILL.md"
  manifest="$ROOT/skill-snapshot/checksums.sha256"
  source_backup="$temp/SKILL.md"
  manifest_backup="$temp/checksums.sha256"
  cp "$source" "$source_backup"
  cp "$manifest" "$manifest_backup"
  cleanup_content_corruption() {
    cp "$source_backup" "$source"
    cp "$manifest_backup" "$manifest"
  }
  trap 'cleanup_content_corruption; fm_test_cleanup' EXIT
  python3 - "$ROOT" <<'PY'
import hashlib
import sys
from pathlib import Path

root = Path(sys.argv[1])
relative = "skill-snapshot/vendor/no-mistakes/no-mistakes/SKILL.md"
source = root / relative
manifest = root / "skill-snapshot/checksums.sha256"
source.write_bytes(source.read_bytes() + b"\ncoordinated corruption\n")
digest = hashlib.sha256(source.read_bytes()).hexdigest()
lines = manifest.read_text(encoding="utf-8").splitlines()
manifest.write_text("\n".join(digest + "  " + relative if line.endswith("  " + relative) else line for line in lines) + "\n", encoding="utf-8")
PY
  rc=0
  out=$("$SKILLS" verify 2>&1) || rc=$?
  cleanup_content_corruption
  trap 'fm_test_cleanup || true' EXIT
  [ "$rc" -ne 0 ] || fail 'snapshot verification accepted coordinated source and checksum corruption'
  assert_contains "$out" 'reviewed provenance digest mismatch: checksums.sha256' \
    'coordinated source corruption did not invalidate the reviewed checksum manifest'
  pass 'snapshot verification authenticates the checksum manifest'
}

test_restore_refuses_different_existing_skill() {
  local temp home out rc
  temp=$(physical_temp_root kcode-skills-collision)
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

test_restore_preflights_late_marker_conflict() {
  local temp home marker before after out rc
  temp=$(physical_temp_root kcode-skills-late-collision)
  home="$temp/home"
  marker="$home/.codex/skills/.threejs-game-skills-managed"
  mkdir -p "$(dirname "$marker")"
  printf 'local manager state\n' > "$marker"
  before=$(find "$home" -mindepth 1 -print | LC_ALL=C sort; shasum -a 256 "$marker")

  rc=0
  out=$($SKILLS restore --home "$home" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'restore accepted a conflicting late manager marker'
  assert_contains "$out" 'refusing to overwrite different manager marker' \
    'late manager-marker collision did not explain its refusal'
  after=$(find "$home" -mindepth 1 -print | LC_ALL=C sort; shasum -a 256 "$marker")
  [ "$after" = "$before" ] || fail 'late restore conflict changed the target home'
  assert_absent "$home/.agents" 'late restore conflict installed generic skills before failing'
  assert_absent "$home/.claude" 'late restore conflict installed Claude skills before failing'
  assert_absent "$home/.grok" 'late restore conflict installed Grok skills before failing'
  pass 'restore preflights late conflicts before changing the target home'
}

test_restore_rolls_back_late_write_failure() {
  local temp home before after out rc
  temp=$(physical_temp_root kcode-skills-write-failure)
  home="$temp/home"
  mkdir -p "$home"
  printf 'preserve me\n' > "$home/existing.txt"
  before=$(find "$home" -mindepth 1 -print -exec shasum -a 256 {} \; 2>/dev/null | LC_ALL=C sort)

  rc=0
  out=$(KCODE_RESTORE_TEST_FAIL_AFTER=60 "$SKILLS" restore --home "$home" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'restore ignored a late promotion failure'
  after=$(find "$home" -mindepth 1 -print -exec shasum -a 256 {} \; 2>/dev/null | LC_ALL=C sort)
  [ "$after" = "$before" ] || fail "late promotion failure left a partial restore: $out"
  [ -z "$(find "$home" -maxdepth 1 -name '.kcode-restore-*' -print -quit)" ] \
    || fail 'late promotion failure left transaction staging behind'
  pass 'late promotion failure rolls back every restored path'
}

write_symlink_swap_hook() {
  local hook=$1 outside=$2
  cat > "$hook" <<EOF_HOOK
#!/usr/bin/env bash
set -euo pipefail
home=\$1
mkdir -p "$outside"
ln -s "$outside" "\$home/.claude"
EOF_HOOK
  chmod +x "$hook"
}

test_restore_staging_parent_swap_cannot_redirect_io() {
  local temp anchor displaced outside home hook out rc
  temp=$(physical_temp_root kcode-skills-staging-parent-race)
  anchor="$temp/anchor"
  displaced="$temp/anchor-original"
  outside="$temp/outside"
  home="$anchor/home"
  hook="$temp/swap-staging-parent"
  mkdir -p "$anchor" "$outside"
  cat > "$hook" <<EOF_HOOK
#!/usr/bin/env bash
set -euo pipefail
mv "$anchor" "$displaced"
ln -s "$outside" "$anchor"
EOF_HOOK
  chmod +x "$hook"

  rc=0
  out=$(KCODE_RESTORE_TEST_AFTER_STAGING_PARENT_OPEN_HOOK="$hook" \
    "$SKILLS" restore --home "$home" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'restore accepted a swapped staging parent'
  [ -z "$(find "$outside" -mindepth 1 -print -quit)" ] \
    || fail "staging parent swap redirected writes outside the requested hierarchy: $out"
  [ -z "$(find "$displaced" -name '.kcode-restore-*' -print -quit)" ] \
    || fail 'staging parent swap left descriptor-owned staging behind'
  pass 'staging remains descriptor-bound across parent swaps and cleans safely'
}

test_restore_rejects_replaced_home_after_staging() {
  local temp home displaced hook out rc
  temp=$(physical_temp_root kcode-skills-home-replacement)
  home="$temp/home"
  displaced="$temp/home-original"
  hook="$temp/replace-home"
  mkdir -p "$home"
  cat > "$hook" <<EOF_HOOK
#!/usr/bin/env bash
set -euo pipefail
mv '$home' '$displaced'
mkdir '$home'
printf 'foreign replacement\n' > '$home/foreign.txt'
EOF_HOOK
  chmod +x "$hook"

  rc=0
  out=$(KCODE_RESTORE_TEST_AFTER_STAGING_MKDIR_HOOK="$hook" \
    "$SKILLS" restore --home "$home" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'restore accepted a replaced home after staging'
  [ "$(cat "$home/foreign.txt")" = 'foreign replacement' ] \
    || fail "restore changed the replacement home: $out"
  [ -z "$(find "$home" -mindepth 1 ! -name foreign.txt -print -quit)" ] \
    || fail 'restore promoted content into the replacement home'
  [ -z "$(find "$displaced" -name '.kcode-restore-*' -print -quit)" ] \
    || fail 'restore left descriptor-owned staging in the displaced home'
  pass 'restore aborts when the requested home identity changes after staging'
}

test_restore_keeps_descriptor_owned_staging_on_name_swap() {
  local temp home hook out rc replacement displaced
  temp=$(physical_temp_root kcode-skills-staging-create-race)
  home="$temp/home"
  hook="$temp/replace-staging"
  mkdir -p "$home"
  cat > "$hook" <<'EOF_HOOK'
#!/usr/bin/env bash
set -euo pipefail
mv "$1" "$1.displaced"
mkdir "$1"
printf 'foreign staging replacement\n' > "$1/foreign.txt"
EOF_HOOK
  chmod +x "$hook"

  rc=0
  out=$(KCODE_RESTORE_TEST_AFTER_STAGING_MKDIR_HOOK="$hook" \
    "$SKILLS" restore --home "$home" 2>&1) || rc=$?
  [ "$rc" -eq 0 ] || fail "restore lost descriptor-owned staging after a name swap: $out"
  replacement=$(find "$home" -maxdepth 1 -name '.kcode-restore-*' ! -name '*.displaced' -print -quit)
  displaced=$(find "$home" -maxdepth 1 -name '.kcode-restore-*.displaced' -print -quit)
  basename "${replacement%.displaced}" | grep -Eq '^\.kcode-restore-[0-9a-f]{48}$' \
    || fail 'staging directory did not use an unpredictable private name'
  [ -n "$replacement" ] && [ "$(cat "$replacement/foreign.txt")" = 'foreign staging replacement' ] \
    || fail "restore changed the foreign staging replacement: $out"
  [ -z "$displaced" ] || fail 'restore stranded the staging directory it created'
  "$SKILLS" verify-home --home "$home" >/dev/null
  pass 'staging stays descriptor-owned after publication and cleans only its own directory'
}

test_restore_uses_open_verified_snapshot_sources() {
  local temp home hook source original displaced foreign expected actual out rc
  temp=$(physical_temp_root kcode-skills-source-race)
  home="$temp/home"
  hook="$temp/replace-source"
  source='skill-snapshot/vendor/vercel-plugin/skills/vercel-storage'
  original="$ROOT/$source"
  displaced="$original.kcode-test-displaced"
  foreign="$original.kcode-test-foreign"
  expected=$(shasum -a 256 "$original/SKILL.md" | awk '{print $1}')
  cat > "$hook" <<EOF_HOOK
#!/usr/bin/env bash
set -euo pipefail
[ "\$1" = '$source' ] || exit 0
mv '$original' '$displaced'
mkdir '$original'
printf '%s\n' 'unchecked replacement' > '$original/SKILL.md'
EOF_HOOK
  chmod +x "$hook"

  cleanup_source_race_fixture() {
    if [ -d "$displaced" ]; then
      [ ! -e "$foreign" ] || rm -rf "$foreign"
      [ ! -e "$original" ] || mv "$original" "$foreign"
      mv "$displaced" "$original"
      [ ! -e "$foreign" ] || rm -rf "$foreign"
    fi
  }
  trap 'cleanup_source_race_fixture; fm_test_cleanup' EXIT
  rc=0
  out=$(KCODE_RESTORE_TEST_AFTER_SOURCE_OPEN_HOOK="$hook" \
    "$SKILLS" restore --home "$home" 2>&1) || rc=$?
  cleanup_source_race_fixture
  trap 'fm_test_cleanup || true' EXIT
  [ "$rc" -eq 0 ] || fail "restore failed while copying an already-open verified source: $out"
  actual=$(shasum -a 256 "$home/.claude/skills/vercel-storage/SKILL.md" | awk '{print $1}')
  [ "$actual" = "$expected" ] || fail 'restore copied unchecked content from a replaced snapshot path'
  pass 'snapshot traversal stays bound to verified no-follow source descriptors'
}

test_restore_rejects_source_mode_change() {
  local temp home hook source executable out rc
  temp=$(physical_temp_root kcode-skills-source-mode)
  home="$temp/home"
  hook="$temp/change-source-mode"
  source='skill-snapshot/vendor/rayfernando-skills/bootstrap-ios'
  executable="$ROOT/$source/scripts/bootstrap-ios-skills.sh"
  cat > "$hook" <<EOF_HOOK
#!/usr/bin/env bash
set -euo pipefail
[ "\$1" = '$source' ] || exit 0
chmod 0644 '$executable'
EOF_HOOK
  chmod +x "$hook"
  cleanup_source_mode_fixture() {
    chmod 0755 "$executable"
  }
  trap 'cleanup_source_mode_fixture; fm_test_cleanup' EXIT

  rc=0
  out=$(KCODE_RESTORE_TEST_AFTER_SOURCE_OPEN_HOOK="$hook" \
    "$SKILLS" restore --home "$home" 2>&1) || rc=$?
  cleanup_source_mode_fixture
  trap 'fm_test_cleanup || true' EXIT
  [ "$rc" -ne 0 ] || fail 'restore accepted a source mode changed after verification'
  assert_contains "$out" 'snapshot mode mismatch during copy' \
    'source mode race did not fail authenticated mode validation'
  assert_absent "$home/.claude/skills/bootstrap-ios" \
    'source mode race installed the changed skill'
  pass 'snapshot copy binds source modes to the authenticated manifest'
}

test_restore_rejects_source_directory_mode_change() {
  local temp home hook source directory out rc
  temp=$(physical_temp_root kcode-skills-source-directory-mode)
  home="$temp/home"
  hook="$temp/change-source-directory-mode"
  source='skill-snapshot/vendor/rayfernando-skills/bootstrap-ios'
  directory="$ROOT/$source/references"
  cat > "$hook" <<EOF_HOOK
#!/usr/bin/env bash
set -euo pipefail
[ "\$1" = '$source' ] || exit 0
chmod 0777 '$directory'
EOF_HOOK
  chmod +x "$hook"
  cleanup_source_directory_mode_fixture() {
    chmod 0755 "$directory"
  }
  trap 'cleanup_source_directory_mode_fixture; fm_test_cleanup' EXIT

  rc=0
  out=$(KCODE_RESTORE_TEST_AFTER_SOURCE_OPEN_HOOK="$hook" \
    "$SKILLS" restore --home "$home" 2>&1) || rc=$?
  cleanup_source_directory_mode_fixture
  trap 'fm_test_cleanup || true' EXIT
  [ "$rc" -ne 0 ] || fail 'restore accepted a source directory mode changed after verification'
  assert_contains "$out" 'snapshot directory mode mismatch during copy' \
    'source directory mode race did not fail safe mode validation'
  assert_absent "$home/.claude/skills/bootstrap-ios" \
    'source directory mode race installed the changed skill'
  pass 'snapshot copy normalizes and validates every source directory mode'
}

test_restore_rejects_source_file_omission() {
  local temp home hook source removed out rc
  temp=$(physical_temp_root kcode-skills-source-omission)
  home="$temp/home"
  hook="$temp/remove-source-file"
  source='skill-snapshot/vendor/no-mistakes/no-mistakes'
  removed="$temp/SKILL.md.removed"
  cat > "$hook" <<EOF_HOOK
#!/usr/bin/env bash
set -euo pipefail
[ "\$1" = '$source' ] || exit 0
mv '$ROOT/$source/SKILL.md' '$removed'
EOF_HOOK
  chmod +x "$hook"
  cleanup_source_omission_fixture() {
    [ ! -e "$removed" ] || mv "$removed" "$ROOT/$source/SKILL.md"
  }
  trap 'cleanup_source_omission_fixture; fm_test_cleanup' EXIT

  rc=0
  out=$(KCODE_RESTORE_TEST_AFTER_SOURCE_OPEN_HOOK="$hook" \
    "$SKILLS" restore --home "$home" 2>&1) || rc=$?
  cleanup_source_omission_fixture
  trap 'fm_test_cleanup || true' EXIT
  [ "$rc" -ne 0 ] || fail 'restore accepted a source with an expected file omitted'
  assert_contains "$out" 'snapshot source path set changed' \
    'source omission did not fail exact checksum path-set validation'
  pass 'snapshot copy requires every checksummed source path exactly once'
}

test_restore_authenticates_control_bytes_before_verification() {
  local temp home hook backup out rc
  temp=$(physical_temp_root kcode-skills-control-baseline)
  home="$temp/home"
  hook="$temp/change-control-before-verify"
  backup="$temp/restore.tsv"
  cp "$ROOT/skill-snapshot/restore.tsv" "$backup"
  cat > "$hook" <<'EOF_HOOK'
#!/usr/bin/env bash
set -euo pipefail
printf '\n' >> "$1"
EOF_HOOK
  chmod +x "$hook"
  cleanup_control_baseline_fixture() {
    cp "$backup" "$ROOT/skill-snapshot/restore.tsv"
  }
  trap 'cleanup_control_baseline_fixture; fm_test_cleanup' EXIT

  rc=0
  out=$(KCODE_RESTORE_TEST_AFTER_CONTROL_DIGEST_HOOK="$hook" \
    "$SKILLS" restore --home "$home" 2>&1) || rc=$?
  cleanup_control_baseline_fixture
  trap 'fm_test_cleanup || true' EXIT
  [ "$rc" -ne 0 ] || fail 'restore trusted control bytes changed before verification'
  assert_contains "$out" 'reviewed provenance digest mismatch: restore.tsv' \
    'pre-verification control change did not invalidate the reviewed baseline'
  assert_absent "$home" 'control baseline failure created the restore home'
  pass 'restore authenticates control bytes before structural verification'
}

test_restore_authenticates_open_control_manifest() {
  local temp home hook backup out rc
  temp=$(physical_temp_root kcode-skills-control-manifest)
  home="$temp/home"
  hook="$temp/change-open-manifest"
  backup="$temp/checksums.sha256"
  cp "$ROOT/skill-snapshot/checksums.sha256" "$backup"
  cat > "$hook" <<EOF_HOOK
#!/usr/bin/env bash
set -euo pipefail
[ "\$2" = 1 ] || exit 0
printf '\n' >> "\$1"
EOF_HOOK
  chmod +x "$hook"
  cleanup_control_manifest_fixture() {
    cp "$backup" "$ROOT/skill-snapshot/checksums.sha256"
  }
  trap 'cleanup_control_manifest_fixture; fm_test_cleanup' EXIT

  rc=0
  out=$(KCODE_RESTORE_TEST_AFTER_CONTROL_OPEN_HOOK="$hook" \
    "$SKILLS" restore --home "$home" 2>&1) || rc=$?
  cleanup_control_manifest_fixture
  trap 'fm_test_cleanup || true' EXIT
  [ "$rc" -ne 0 ] || fail 'restore accepted changed descriptor-read control bytes'
  assert_contains "$out" 'checksum manifest bytes changed after verification' \
    'control-manifest change did not fail authenticated descriptor validation'
  pass 'restore authenticates the exact control-manifest bytes it consumes'
}

test_restore_preserves_unowned_staging_entries() {
  local temp home hook out rc foreign
  temp=$(physical_temp_root kcode-skills-staging-concurrent-entry)
  home="$temp/home"
  hook="$temp/add-unowned-staging-entry"
  mkdir -p "$home"
  cat > "$hook" <<'EOF_HOOK'
#!/usr/bin/env bash
set -euo pipefail
printf 'foreign concurrent staging data\n' > "$1/foreign.txt"
EOF_HOOK
  chmod +x "$hook"

  rc=0
  out=$(KCODE_RESTORE_TEST_BEFORE_STAGING_CLEANUP_HOOK="$hook" \
    "$SKILLS" restore --home "$home" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'restore accepted an unowned concurrent staging entry'
  assert_contains "$out" 'staging contains unowned concurrent entries' \
    'unowned staging entry did not produce a safe cleanup failure'
  assert_absent "$home/.agents" 'unowned staging entry failure left promoted generic skills'
  assert_absent "$home/.claude" 'unowned staging entry failure left promoted Claude skills'
  foreign=$(find "$temp" -name foreign.txt -print -quit)
  [ -n "$foreign" ] && [ "$(cat "$foreign")" = 'foreign concurrent staging data' ] \
    || fail "staging cleanup removed or changed concurrent data: $out"
  pass 'staging cleanup preserves unowned concurrent entries and rolls back'
}

test_restore_rolls_back_on_staging_cleanup_failure() {
  local temp home hook out rc
  temp=$(physical_temp_root kcode-skills-cleanup-failure)
  home="$temp/home"
  hook="$temp/destroy-owned-staging"
  mkdir -p "$home"
  cat > "$hook" <<'EOF_HOOK'
#!/usr/bin/env bash
set -euo pipefail
mv "$1" "$1.displaced"
rm -rf "$1.displaced"
mkdir "$1"
printf 'foreign replacement\n' > "$1/foreign.txt"
EOF_HOOK
  chmod +x "$hook"

  rc=0
  out=$(KCODE_RESTORE_TEST_BEFORE_STAGING_CLEANUP_HOOK="$hook" \
    "$SKILLS" restore --home "$home" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'restore accepted loss of its descriptor-owned staging directory'
  assert_absent "$home/.agents" 'staging cleanup failure left promoted generic skills'
  assert_absent "$home/.claude" 'staging cleanup failure left promoted Claude skills'
  [ "$(find "$temp" -name foreign.txt -exec cat {} \;)" = 'foreign replacement' ] \
    || fail "staging cleanup rollback changed the foreign replacement: $out"
  pass 'staging cleanup failures roll back promoted paths and preserve replacements'
}

test_restore_revalidates_promotion_ancestors() {
  local temp home outside hook out rc
  temp=$(physical_temp_root kcode-skills-promotion-symlink)
  home="$temp/home"
  outside="$temp/outside"
  hook="$temp/swap-parent"
  mkdir -p "$home"
  write_symlink_swap_hook "$hook" "$outside"

  rc=0
  out=$(KCODE_RESTORE_TEST_HOOK="$hook" "$SKILLS" restore --home "$home" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'restore followed an ancestor symlink introduced after preflight'
  [ -L "$home/.claude" ] || fail 'restore rollback removed the foreign symlink'
  [ -z "$(find "$outside" -mindepth 1 -print -quit)" ] \
    || fail "restore wrote through the post-preflight symlink: $out"
  assert_absent "$home/.agents" 'promotion symlink failure left earlier restored skills'
  assert_absent "$home/.grok" 'promotion symlink failure left later restored skills'
  pass 'promotion revalidates ancestors without following late symlinks'
}

test_restore_preserves_concurrent_destination() {
  local temp home hook destination out rc
  temp=$(physical_temp_root kcode-skills-concurrent-destination)
  home="$temp/home"
  hook="$temp/create-destination"
  destination="$home/.claude/skills/workflow"
  mkdir -p "$home"
  cat > "$hook" <<'EOF_HOOK'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$1/.claude/skills/workflow"
printf 'foreign concurrent object\n' > "$1/.claude/skills/workflow/SKILL.md"
EOF_HOOK
  chmod +x "$hook"

  rc=0
  out=$(KCODE_RESTORE_TEST_HOOK="$hook" "$SKILLS" restore --home "$home" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'restore replaced a destination created after preflight'
  [ "$(cat "$destination/SKILL.md")" = 'foreign concurrent object' ] \
    || fail "rollback removed or changed a concurrent destination: $out"
  assert_absent "$home/.agents" 'concurrent destination failure left earlier restored skills'
  pass 'rollback preserves paths the transaction did not create'
}

test_restore_rollback_preserves_concurrent_child() {
  local temp home hook destination out rc
  temp=$(physical_temp_root kcode-skills-concurrent-child)
  home="$temp/home"
  hook="$temp/add-child"
  mkdir -p "$home"
  cat > "$hook" <<'EOF_HOOK'
#!/usr/bin/env bash
set -euo pipefail
[ "$2" = 1 ] || exit 0
printf 'foreign concurrent child\n' > "$1/concurrent.txt"
EOF_HOOK
  chmod +x "$hook"

  rc=0
  out=$(KCODE_RESTORE_TEST_AFTER_PROMOTE_HOOK="$hook" KCODE_RESTORE_TEST_FAIL_AFTER=1 \
    "$SKILLS" restore --home "$home" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'restore ignored failure after a concurrent child appeared'
  destination=$(dirname "$(find "$home" -type f -name concurrent.txt -print -quit)")
  [ "$(cat "$destination/concurrent.txt")" = 'foreign concurrent child' ] \
    || fail "rollback removed or changed a concurrent child: $out"
  assert_absent "$destination/SKILL.md" 'rollback retained captured files beside a concurrent child'
  pass 'rollback removes only captured entries and preserves concurrent children'
}

test_restore_journals_before_post_rename_failure() {
  local temp home hook out rc
  temp=$(physical_temp_root kcode-skills-post-rename-failure)
  home="$temp/home"
  hook="$temp/fail-after-rename"
  mkdir -p "$home"
  cat > "$hook" <<'EOF_HOOK'
#!/usr/bin/env bash
exit 23
EOF_HOOK
  chmod +x "$hook"

  rc=0
  out=$(KCODE_RESTORE_TEST_AFTER_RENAME_HOOK="$hook" \
    "$SKILLS" restore --home "$home" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'restore ignored a failure immediately after publication'
  assert_absent "$home/.agents/skills/no-mistakes" \
    "post-rename failure left an unjournaled promotion: $out"
  pass 'promotion is rollback-owned before failure-prone post-rename work'
}

test_restore_revalidates_compatible_existing_entries() {
  local temp home hook out rc
  temp=$(physical_temp_root kcode-skills-existing-revalidation)
  home="$temp/home"
  hook="$temp/change-existing"
  "$SKILLS" restore --home "$home" >/dev/null
  cat > "$hook" <<'EOF_HOOK'
#!/usr/bin/env bash
set -euo pipefail
printf 'changed after preflight\n' > "$1/.claude/skills/workflow/SKILL.md"
printf 'stale after preflight\n' > "$1/.codex/skills/.threejs-game-skills-managed"
EOF_HOOK
  chmod +x "$hook"

  rc=0
  out=$(KCODE_RESTORE_TEST_BEFORE_FINAL_VALIDATION_HOOK="$hook" \
    "$SKILLS" restore --home "$home" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'restore accepted compatible entries changed before commit'
  assert_contains "$out" 'restore destination changed before commit' \
    'commit-time revalidation did not identify the changed existing entry'
  pass 'restore revalidates every compatible skill and marker before commit'
}

test_restore_reports_quarantine_restore_collision() {
  local temp home destination hook collision_hook out rc recovery
  temp=$(physical_temp_root kcode-skills-rollback-collision)
  home="$temp/home"
  destination="$home/.agents/skills/no-mistakes"
  hook="$temp/add-concurrent-child"
  collision_hook="$temp/recreate-destination"
  mkdir -p "$home"
  cat > "$hook" <<'EOF_HOOK'
#!/usr/bin/env bash
set -euo pipefail
[ "$2" = 1 ] || exit 0
printf 'preserve concurrent child\n' > "$1/concurrent.txt"
EOF_HOOK
  cat > "$collision_hook" <<EOF_HOOK
#!/usr/bin/env bash
set -euo pipefail
[ "\$1" = no-mistakes ] || exit 0
mkdir -p "$destination"
printf 'foreign replacement\n' > "$destination/foreign.txt"
EOF_HOOK
  chmod +x "$hook" "$collision_hook"

  rc=0
  out=$(KCODE_RESTORE_TEST_AFTER_PROMOTE_HOOK="$hook" \
    KCODE_RESTORE_TEST_BEFORE_QUARANTINE_RESTORE_HOOK="$collision_hook" \
    KCODE_RESTORE_TEST_FAIL_AFTER=1 "$SKILLS" restore --home "$home" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'restore ignored an unsafe rollback name collision'
  assert_contains "$out" 'safe rollback was impossible' \
    'rollback collision did not fail loudly with recovery details'
  [ "$(cat "$destination/foreign.txt")" = 'foreign replacement' ] \
    || fail 'rollback collision changed the concurrent replacement'
  recovery=$(find "$home/.agents/skills" -maxdepth 1 -name 'kcode-restore-recovery-*' -print -quit)
  [ -n "$recovery" ] || fail 'rollback collision did not preserve displaced concurrent data visibly'
  [ "$(cat "$recovery/concurrent.txt")" = 'preserve concurrent child' ] \
    || fail 'rollback collision lost displaced concurrent data'
  [ -z "$(find "$home" -name '.kcode-rollback-*' -print -quit)" ] \
    || fail 'rollback collision stranded a hidden quarantine artifact'
  pass 'rollback collisions preserve both objects and report visible recovery data'
}

test_restore_does_not_journal_replaced_promotion() {
  local temp home hook out rc
  temp=$(physical_temp_root kcode-skills-replaced-promotion)
  home="$temp/home"
  hook="$temp/replace-promotion"
  mkdir -p "$home"
  cat > "$hook" <<'EOF_HOOK'
#!/usr/bin/env bash
set -euo pipefail
[ "$2" = 1 ] || exit 0
mv "$1" "$1.displaced"
rm -rf "$1.displaced"
mkdir "$1"
printf 'foreign replacement\n' > "$1/foreign.txt"
EOF_HOOK
  chmod +x "$hook"

  rc=0
  out=$(KCODE_RESTORE_TEST_AFTER_RENAME_HOOK="$hook" \
    "$SKILLS" restore --home "$home" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'restore accepted a promoted path replaced before ownership verification'
  [ "$(find "$home" -type f -name foreign.txt -exec cat {} \;)" = 'foreign replacement' ] \
    || fail "rollback removed or changed a foreign replacement: $out"
  pass 'promotion ownership uses staged identity and preserves replacements'
}

test_restore_does_not_journal_replaced_directory() {
  local temp home hook private_name out rc
  temp=$(physical_temp_root kcode-skills-replaced-directory)
  home="$temp/home"
  hook="$temp/replace-directory"
  mkdir -p "$home"
  cat > "$hook" <<EOF_HOOK
#!/usr/bin/env bash
set -euo pipefail
[ "\$1" = .agents ] || exit 0
printf '%s\n' "\$2" > "$temp/private-name"
mv "$home/.agents" "$home/.agents.displaced"
rm -rf "$home/.agents.displaced"
mkdir "$home/.agents"
printf 'foreign directory\n' > "$home/.agents/foreign.txt"
EOF_HOOK
  chmod +x "$hook"

  rc=0
  out=$(KCODE_RESTORE_TEST_AFTER_DIRECTORY_RENAME_HOOK="$hook" \
    "$SKILLS" restore --home "$home" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'restore accepted a parent directory replaced during creation'
  private_name=$(cat "$temp/private-name")
  printf '%s\n' "$private_name" | grep -Eq '^\.kcode-directory-[0-9a-f]{48}$' \
    || fail 'parent-directory temporary did not use an unpredictable private name'
  [ "$(cat "$home/.agents/foreign.txt")" = 'foreign directory' ] \
    || fail "rollback removed or changed a foreign parent directory: $out"
  [ ! -e "$home/$private_name" ] || fail 'restore stranded its private parent-directory temporary'
  pass 'directory ownership is captured before publication'
}

test_restore_rejects_home_ancestor_swap_before_promotion() {
  local temp anchor displaced outside home hook out rc
  temp=$(physical_temp_root kcode-skills-home-canonicalization-race)
  anchor="$temp/anchor"
  displaced="$temp/anchor-original"
  outside="$temp/outside"
  home="$anchor/home"
  hook="$temp/swap-home-ancestor"
  mkdir -p "$anchor" "$outside"
  cat > "$hook" <<EOF_HOOK
#!/usr/bin/env bash
set -euo pipefail
mv '$anchor' '$displaced'
ln -s '$outside' '$anchor'
EOF_HOOK
  chmod +x "$hook"

  rc=0
  out=$(KCODE_RESTORE_TEST_BEFORE_PROMOTION_HOOK="$hook" \
    "$SKILLS" restore --home "$home" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'restore accepted a home ancestor swapped before promotion'
  [ -z "$(find "$outside" -mindepth 1 -print -quit)" ] \
    || fail "home ancestor swap redirected restore outside the requested hierarchy: $out"
  [ -z "$(find "$displaced" -name '.kcode-restore-*' -print -quit)" ] \
    || fail 'home ancestor swap left transaction staging behind'
  pass 'promotion walks the lexical home path without following swapped symlinks'
}

test_restore_rejects_symlinked_ancestor() {
  local temp home outside out rc
  temp=$(physical_temp_root kcode-skills-symlink-escape)
  home="$temp/home"
  outside="$temp/outside"
  mkdir -p "$home" "$outside"
  ln -s "$outside" "$home/.claude"

  rc=0
  out=$($SKILLS restore --home "$home" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'restore accepted a symlinked harness root'
  assert_contains "$out" 'restore path contains symlinked component' \
    'symlinked-ancestor refusal did not identify the unsafe path'
  [ -z "$(find "$outside" -mindepth 1 -print -quit)" ] \
    || fail 'restore wrote through a symlinked ancestor outside its home'
  assert_absent "$home/.agents" 'symlink refusal installed generic skills before failing'
  pass 'restore rejects ancestor symlinks without escaping its home'
}

test_restore_rejects_symlink_above_nonexistent_home() {
  local temp outside home out rc
  temp=$(physical_temp_root kcode-skills-home-ancestor-symlink)
  outside="$temp/outside"
  mkdir -p "$outside"
  ln -s "$outside" "$temp/linked-parent"
  home="$temp/linked-parent/missing/home"

  rc=0
  out=$($SKILLS restore --home "$home" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'restore accepted a symlink above a nonexistent home'
  assert_contains "$out" 'restore home contains a symlinked component' \
    'requested-home ancestor refusal did not identify the unsafe path'
  [ -z "$(find "$outside" -mindepth 1 -print -quit)" ] \
    || fail 'restore wrote through a symlink above a nonexistent home'
  pass 'restore validates requested-home ancestors before canonicalization'
}

test_verify_home_rejects_stale_marker() {
  local temp home marker out rc
  temp=$(physical_temp_root kcode-skills-stale-marker)
  home="$temp/home"
  $SKILLS restore --home "$home" >/dev/null
  marker="$home/.codex/skills/.threejs-game-skills-managed"
  printf 'stale manager state\n' > "$marker"

  rc=0
  out=$($SKILLS verify-home --home "$home" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'verify-home accepted a stale manager marker'
  assert_contains "$out" 'Three.js manager marker differs or is missing' \
    'stale manager marker failure was not identified'
  pass 'verify-home compares manager marker contents byte-for-byte'
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
  temp=$(physical_temp_root kcode-skills-live)
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
  write_pi_package_inventory "$home"

  out=$($SKILLS verify-live --from-home "$ROOT" --user-home "$home")
  assert_contains "$out" 'live roots match the complete captured inventory' \
    'classified live fixture did not verify'

  printf '{"name":"pi-claude-bridge","version":"0.6.1"}\n' \
    > "$home/.pi/agent/npm/node_modules/pi-claude-bridge/package.json"
  rc=0
  out=$($SKILLS verify-live --from-home "$ROOT" --user-home "$home" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'live inventory accepted a changed Pi package version'
  assert_contains "$out" 'installed Pi package does not match captured version' \
    'Pi package drift failure did not identify the changed package'
  printf '{"name":"pi-claude-bridge","version":"0.6.2"}\n' \
    > "$home/.pi/agent/npm/node_modules/pi-claude-bridge/package.json"

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
test_restore_stages_on_destination_filesystem
test_restore_nested_target_mount
test_restore_preserves_and_verifies_executable_modes
test_snapshot_rejects_corrupt_provenance
test_snapshot_rejects_coordinated_content_corruption
test_restore_refuses_different_existing_skill
test_restore_preflights_late_marker_conflict
test_restore_rolls_back_late_write_failure
test_restore_staging_parent_swap_cannot_redirect_io
test_restore_rejects_replaced_home_after_staging
test_restore_keeps_descriptor_owned_staging_on_name_swap
test_restore_uses_open_verified_snapshot_sources
test_restore_rejects_source_mode_change
test_restore_rejects_source_directory_mode_change
test_restore_rejects_source_file_omission
test_restore_authenticates_control_bytes_before_verification
test_restore_authenticates_open_control_manifest
test_restore_preserves_unowned_staging_entries
test_restore_rolls_back_on_staging_cleanup_failure
test_restore_revalidates_promotion_ancestors
test_restore_preserves_concurrent_destination
test_restore_rollback_preserves_concurrent_child
test_restore_journals_before_post_rename_failure
test_restore_revalidates_compatible_existing_entries
test_restore_reports_quarantine_restore_collision
test_restore_does_not_journal_replaced_promotion
test_restore_does_not_journal_replaced_directory
test_restore_rejects_home_ancestor_swap_before_promotion
test_restore_rejects_symlinked_ancestor
test_restore_rejects_symlink_above_nonexistent_home
test_verify_home_rejects_stale_marker
test_manifest_covers_every_captured_source_once
test_live_inventory_detects_unclassified_skill
