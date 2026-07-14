#!/usr/bin/env bash
# kcode-skills.sh - verify, inventory, and restore k-code's captured skill setup.
#
# skill-snapshot/restore.tsv is the single owner of source-to-harness placement.
# skill-snapshot/sources.tsv owns source, revision, and license provenance.
# skill-snapshot/harness-managed.tsv owns exact references for version-coupled
# resources that must come from their harness instead of this repository.
#
# Usage:
#   bin/kcode-skills.sh inventory
#   bin/kcode-skills.sh verify
#   bin/kcode-skills.sh restore --home <empty-or-compatible-home>
#   bin/kcode-skills.sh verify-home --home <restored-home>
#   bin/kcode-skills.sh verify-live --from-home <firstmate-home> --user-home <home>
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNAPSHOT="$ROOT/skill-snapshot"
RESTORE_MANIFEST="$SNAPSHOT/restore.tsv"
CHECKSUMS="$SNAPSHOT/checksums.sha256"

usage() {
  sed -n '3,13p' "$0" >&2
}

fail() {
  printf 'kcode-skills: %s\n' "$*" >&2
  exit 1
}

target_dir() {
  local home=$1 target=$2
  case "$target" in
    generic) printf '%s/.agents/skills\n' "$home" ;;
    claude) printf '%s/.claude/skills\n' "$home" ;;
    codex) printf '%s/.codex/skills\n' "$home" ;;
    grok) printf '%s/.grok/skills\n' "$home" ;;
    *) fail "unknown target root in restore manifest: $target" ;;
  esac
}

manifest_rows() {
  awk -F '\t' 'NF && $1 !~ /^#/ {print}' "$RESTORE_MANIFEST"
}

hash_check() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -c "$CHECKSUMS" >/dev/null
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum -c "$CHECKSUMS" >/dev/null
  else
    fail 'neither shasum nor sha256sum is available'
  fi
}

verify_snapshot() {
  local listed actual tracked source target name declared duplicate front_name
  for file in sources.tsv roots.tsv harness-managed.tsv restore.tsv checksums.sha256 README.md; do
    [ -f "$SNAPSHOT/$file" ] || fail "missing skill-snapshot/$file"
  done

  cd "$ROOT"
  hash_check || fail 'captured skill checksum mismatch'

  listed=$(awk '{print $2}' "$CHECKSUMS" | LC_ALL=C sort)
  actual=$(find .agents/skills skills skill-snapshot/vendor -type f -print | LC_ALL=C sort)
  [ "$listed" = "$actual" ] || fail 'checksums.sha256 does not cover the exact captured source file set'
  tracked=$(git ls-files -- .agents/skills skills skill-snapshot/vendor | LC_ALL=C sort)
  [ "$listed" = "$tracked" ] || fail 'captured source files must all be tracked for clean-clone restore'

  if find skill-snapshot/vendor -type l -print -quit | grep -q .; then
    fail 'vendored skills must not contain symlinks'
  fi
  [ -L .claude/skills ] || fail '.claude/skills must remain a relative symlink'
  [ "$(readlink .claude/skills)" = '../.agents/skills' ] \
    || fail '.claude/skills must point to ../.agents/skills'

  duplicate=$(manifest_rows | awk -F '\t' '{key=$2 FS $3; seen[key]++} END {for (key in seen) if (seen[key] > 1) print key}' | head -1)
  [ -z "$duplicate" ] || fail "duplicate restore target and skill: $duplicate"

  while IFS=$'\t' read -r source target name; do
    case "$source" in
      skill-snapshot/vendor/*) ;;
      *) fail "restore source escapes vendored layout: $source" ;;
    esac
    [ -f "$ROOT/$source/SKILL.md" ] || fail "missing skill source: $source/SKILL.md"
    [ "${source##*/}" = "$name" ] || fail "restore name does not match source directory: $source"
    target_dir /tmp "$target" >/dev/null
    front_name=$(awk '
      /^---[[:space:]]*$/ {if (front) exit; front=1; next}
      front && /^name:[[:space:]]*/ {
        sub(/^name:[[:space:]]*/, ""); gsub(/^['"'"'"]|['"'"'"]$/, ""); print; exit
      }
    ' "$ROOT/$source/SKILL.md")
    [ "$front_name" = "$name" ] || fail "frontmatter name mismatch in $source: ${front_name:-missing}"
  done < <(manifest_rows)

  declared=$(grep -vc '^#' "$RESTORE_MANIFEST")
  printf 'kcode-skills: verified %s restore placements and %s captured files.\n' \
    "$declared" "$(wc -l < "$CHECKSUMS" | tr -d ' ')"
}

skill_names() {
  local directory=$1
  [ -d "$directory" ] || return 0
  find -L "$directory" -mindepth 2 -maxdepth 2 -type f -name SKILL.md -print \
    | while IFS= read -r skill_file; do basename "$(dirname "$skill_file")"; done \
    | LC_ALL=C sort
}

manifest_target_names() {
  local target=$1 include_plugin=${2:-yes}
  manifest_rows | awk -F '\t' -v target="$target" -v include_plugin="$include_plugin" '
    $2 == target && (include_plugin == "yes" || $1 !~ /vendor\/vercel-plugin\//) {print $3}
  ' | LC_ALL=C sort
}

managed_names() {
  local harness=$1 component=$2
  awk -F '\t' -v harness="$harness" -v component="$component" '
    $1 == harness && $2 == component {
      count=split($6, names, ",")
      for (i=1; i<=count; i++) print names[i]
    }
  ' "$SNAPSHOT/harness-managed.tsv" | LC_ALL=C sort
}

assert_names() {
  local label=$1 actual=$2 expected=$3
  [ "$actual" = "$expected" ] || {
    printf 'kcode-skills: live inventory mismatch for %s\n' "$label" >&2
    printf '%s\n' '--- expected ---' "$expected" '--- actual ---' "$actual" >&2
    exit 1
  }
}

assert_no_source_links() {
  local label=$1 directory=$2 link
  [ -d "$directory" ] || return 0
  link=$(find "$directory" -type l -print -quit)
  [ -z "$link" ] || fail "live inventory has an unclassified symlink in $label: $link"
}

verify_target_copies() {
  local user_home=$1 target=$2 directory source row_target name
  directory=$(target_dir "$user_home" "$target")
  while IFS=$'\t' read -r source row_target name; do
    [ "$row_target" = "$target" ] || continue
    case "$source" in
      skill-snapshot/vendor/vercel-plugin/*) continue ;;
    esac
    diff -qr "$ROOT/$source" "$directory/$name" >/dev/null 2>&1 \
      || fail "live $target skill differs from the captured source: $directory/$name"
  done < <(manifest_rows)
}

claude_plugin_paths() {
  local metadata=$1
  python3 - "$metadata" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)
for plugin_id, records in sorted(data.get("plugins", {}).items()):
    for record in records:
        print(f"{plugin_id}\t{record.get('installPath', '')}")
PY
}

verify_live() {
  local from_home=$1 user_home=$2 expected actual plugin_metadata plugin_dir plugin_id install_path
  [ -d "$from_home/.agents/skills" ] || fail "missing live project skill root: $from_home/.agents/skills"
  [ -d "$from_home/skills" ] || fail "missing live public skill root: $from_home/skills"
  user_home=$(cd "$user_home" && pwd -P)

  diff -qr "$from_home/.agents/skills" "$ROOT/.agents/skills" >/dev/null 2>&1 \
    || fail 'live Firstmate internal skills differ from the mirrored repository skills'
  diff -qr "$from_home/skills" "$ROOT/skills" >/dev/null 2>&1 \
    || fail 'live Firstmate public skills differ from the mirrored repository skills'

  assert_no_source_links 'generic skills' "$user_home/.agents/skills"
  assert_no_source_links 'Claude user skills' "$user_home/.claude/skills"
  assert_no_source_links 'Codex user skills' "$user_home/.codex/skills"
  assert_no_source_links 'Grok user skills' "$user_home/.grok/skills"
  assert_no_source_links 'Grok bundled skills' "$user_home/.grok/bundled/skills"

  expected=$(manifest_target_names generic)
  actual=$(skill_names "$user_home/.agents/skills")
  assert_names 'generic user skill root' "$actual" "$expected"

  expected=$(manifest_target_names claude no)
  actual=$(skill_names "$user_home/.claude/skills")
  assert_names 'Claude user skill root' "$actual" "$expected"

  expected=$(manifest_target_names codex)
  actual=$(skill_names "$user_home/.codex/skills")
  assert_names 'Codex user skill root' "$actual" "$expected"

  expected=$(printf '%s\n%s\n' "$(manifest_target_names grok)" \
    "$(managed_names Grok 'grok user stock skills')" | sed '/^$/d' | LC_ALL=C sort)
  actual=$(skill_names "$user_home/.grok/skills")
  assert_names 'Grok user skill root' "$actual" "$expected"

  expected=$(managed_names Codex codex-cli)
  actual=$(skill_names "$user_home/.codex/skills/.system")
  assert_names 'Codex system skill root' "$actual" "$expected"

  expected=$(managed_names Grok 'grok bundled skills')
  actual=$(skill_names "$user_home/.grok/bundled/skills")
  assert_names 'Grok bundled skill root' "$actual" "$expected"

  actual=$(skill_names "$user_home/.pi/agent/skills")
  [ -z "$actual" ] || fail "unclassified Pi skills found: $actual"

  verify_target_copies "$user_home" generic
  verify_target_copies "$user_home" claude
  verify_target_copies "$user_home" codex
  verify_target_copies "$user_home" grok

  plugin_metadata="$user_home/.claude/plugins/installed_plugins.json"
  [ -f "$plugin_metadata" ] || fail "missing Claude plugin inventory: $plugin_metadata"
  plugin_dir=${KCODE_VERCEL_PLUGIN_DIR:-}
  while IFS=$'\t' read -r plugin_id install_path; do
    if [ "$plugin_id" = 'vercel@claude-plugins-official' ]; then
      [ -z "$plugin_dir" ] && plugin_dir=$install_path
    elif find "$install_path" -type f -name SKILL.md -print -quit 2>/dev/null | grep -q .; then
      fail "unclassified installed Claude plugin skills: $plugin_id"
    fi
  done < <(claude_plugin_paths "$plugin_metadata")
  [ -n "$plugin_dir" ] && [ -d "$plugin_dir/skills" ] \
    || fail 'active Vercel Claude plugin skills were not found'
  diff -qr "$plugin_dir/skills" "$ROOT/skill-snapshot/vendor/vercel-plugin/skills" >/dev/null 2>&1 \
    || fail 'active Vercel Claude plugin skills differ from the captured source'
  diff -q "$plugin_dir/.claude-plugin/plugin.json" \
    "$ROOT/skill-snapshot/vendor/vercel-plugin/plugin.json" >/dev/null 2>&1 \
    || fail 'active Vercel Claude plugin metadata differs from the captured version'

  printf 'kcode-skills: live roots match the complete captured inventory.\n'
}

install_skill() {
  local source=$1 destination=$2 temporary
  if [ -e "$destination" ] || [ -L "$destination" ]; then
    diff -qr "$source" "$destination" >/dev/null 2>&1 \
      || fail "refusing to overwrite different installed skill: $destination"
    return 0
  fi

  mkdir -p "$(dirname "$destination")"
  temporary="${destination}.kcode-tmp.$$"
  [ ! -e "$temporary" ] || fail "temporary restore path already exists: $temporary"
  cp -R "$source" "$temporary"
  mv "$temporary" "$destination"
}

write_threejs_marker() {
  local home=$1 target=$2 directory marker expected
  directory=$(target_dir "$home" "$target")
  marker="$directory/.threejs-game-skills-managed"
  expected=$(manifest_rows | awk -F '\t' -v target="$target" \
    '$2 == target && $1 ~ /vendor\/threejs-game-skills\// {print $3}' | LC_ALL=C sort)
  [ -n "$expected" ] || return 0
  mkdir -p "$directory"
  if [ -e "$marker" ]; then
    cmp -s "$marker" <(printf '%s\n' "$expected") \
      || fail "refusing to overwrite different manager marker: $marker"
  else
    printf '%s\n' "$expected" > "$marker"
  fi
}

restore_home() {
  local home=$1 source target name directory count=0
  [ -n "$home" ] || fail 'restore requires a non-empty --home path'
  mkdir -p "$home"
  home=$(cd "$home" && pwd -P)
  verify_snapshot >/dev/null

  while IFS=$'\t' read -r source target name; do
    directory=$(target_dir "$home" "$target")
    install_skill "$ROOT/$source" "$directory/$name"
    count=$((count + 1))
  done < <(manifest_rows)

  write_threejs_marker "$home" claude
  write_threejs_marker "$home" codex
  printf 'kcode-skills: restored %s placements under %s.\n' "$count" "$home"
  printf 'kcode-skills: harness-managed resources remain pinned in skill-snapshot/harness-managed.tsv.\n'
}

verify_home() {
  local home=$1 source target name directory count=0
  [ -d "$home" ] || fail "restored home does not exist: $home"
  home=$(cd "$home" && pwd -P)
  verify_snapshot >/dev/null

  while IFS=$'\t' read -r source target name; do
    directory=$(target_dir "$home" "$target")
    diff -qr "$ROOT/$source" "$directory/$name" >/dev/null 2>&1 \
      || fail "restored skill differs or is missing: $directory/$name"
    count=$((count + 1))
  done < <(manifest_rows)

  for target in claude codex; do
    directory=$(target_dir "$home" "$target")
    [ -f "$directory/.threejs-game-skills-managed" ] \
      || fail "missing Three.js manager marker in $directory"
  done
  printf 'kcode-skills: verified %s restored placements under %s.\n' "$count" "$home"
}

command=${1:-}
case "$command" in
  inventory)
    [ "$#" -eq 1 ] || { usage; exit 2; }
    for file in roots.tsv sources.tsv harness-managed.tsv restore.tsv; do
      printf '## skill-snapshot/%s\n' "$file"
      cat "$SNAPSHOT/$file"
    done
    ;;
  verify)
    [ "$#" -eq 1 ] || { usage; exit 2; }
    verify_snapshot
    ;;
  restore|verify-home)
    [ "$#" -eq 3 ] && [ "$2" = '--home' ] || { usage; exit 2; }
    if [ "$command" = restore ]; then
      restore_home "$3"
    else
      verify_home "$3"
    fi
    ;;
  verify-live)
    [ "$#" -eq 5 ] && [ "$2" = '--from-home' ] && [ "$4" = '--user-home' ] \
      || { usage; exit 2; }
    verify_snapshot >/dev/null
    verify_live "$3" "$5"
    ;;
  *)
    usage
    exit 2
    ;;
esac
