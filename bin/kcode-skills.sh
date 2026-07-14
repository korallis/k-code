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

absolute_path() {
  python3 - "$1" <<'PY'
import os
import sys

print(os.path.realpath(sys.argv[1]))
PY
}

reject_requested_home_symlinks() {
  python3 - "$1" <<'PY'
import os
import sys

path = sys.argv[1]
current = os.path.sep if os.path.isabs(path) else os.getcwd()
for component in path.split(os.path.sep):
    if component in ("", "."):
        continue
    if component == "..":
        current = os.path.dirname(current)
        continue
    current = os.path.join(current, component)
    if os.path.lexists(current) and os.path.islink(current):
        print(current)
        raise SystemExit(1)
PY
}

reject_symlink_components() {
  local home=$1 path=$2
  python3 - "$home" "$path" <<'PY'
import os
import sys

home, path = map(os.path.abspath, sys.argv[1:])
relative = os.path.relpath(path, home)
current = home
for component in (() if relative == "." else relative.split(os.path.sep)):
    current = os.path.join(current, component)
    if os.path.lexists(current) and os.path.islink(current):
        print(current)
        raise SystemExit(1)
PY
}

assert_restore_path() {
  local home=$1 path=$2 escaped link
  escaped=$(python3 - "$home" "$path" <<'PY'
import os
import sys

home, path = map(os.path.abspath, sys.argv[1:])
try:
    inside = os.path.commonpath((home, path)) == home
except ValueError:
    inside = False
print("no" if inside else "yes")
PY
)
  [ "$escaped" = no ] || fail "restore destination escapes requested home: $path"
  link=$(reject_symlink_components "$home" "$path") \
    || fail "restore path contains symlinked component: $link"
}

preflight_parent() {
  local path=$1 parent
  parent=$(dirname "$path")
  while [ ! -e "$parent" ] && [ ! -L "$parent" ]; do
    [ "$(dirname "$parent")" != "$parent" ] || break
    parent=$(dirname "$parent")
  done
  [ -d "$parent" ] || fail "restore parent is not a directory: $parent"
  [ ! -L "$parent" ] || fail "restore parent is a symlink: $parent"
}

preflight_skill() {
  local home=$1 source=$2 destination=$3
  assert_restore_path "$home" "$destination"
  if [ -e "$destination" ] || [ -L "$destination" ]; then
    diff -qr "$source" "$destination" >/dev/null 2>&1 \
      || fail "refusing to overwrite different installed skill: $destination"
  fi
  preflight_parent "$destination"
}

threejs_marker_content() {
  local target=$1
  manifest_rows | awk -F '\t' -v target="$target" \
    '$2 == target && $1 ~ /vendor\/threejs-game-skills\// {print $3}' | LC_ALL=C sort
}

preflight_threejs_marker() {
  local home=$1 target=$2 directory marker expected
  directory=$(target_dir "$home" "$target")
  marker="$directory/.threejs-game-skills-managed"
  expected=$(threejs_marker_content "$target")
  [ -n "$expected" ] || return 0
  assert_restore_path "$home" "$marker"
  if [ -e "$marker" ] || [ -L "$marker" ]; then
    cmp -s "$marker" <(printf '%s\n' "$expected") \
      || fail "refusing to overwrite different manager marker: $marker"
  fi
  preflight_parent "$marker"
}

file_sha256() {
  local file=$1
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    sha256sum "$file" | awk '{print $1}'
  fi
}

promote_restore_plan() {
  local home=$1 manifest_digest=$2 checksums_digest=$3
  python3 - "$home" "$ROOT" "$RESTORE_MANIFEST" "$CHECKSUMS" \
    "$manifest_digest" "$checksums_digest" <<'PY'
import ctypes
import errno
import hashlib
import os
import platform
import secrets
import stat
import subprocess
import sys

home, root, manifest, checksums_path = map(os.path.abspath, sys.argv[1:5])
manifest_digest, checksums_digest = sys.argv[5:7]
flags = os.O_RDONLY | os.O_DIRECTORY
if hasattr(os, "O_NOFOLLOW"):
    flags |= os.O_NOFOLLOW
libc = ctypes.CDLL(None, use_errno=True)
system = platform.system()
created_dirs = []
created_paths = []
fds = {}
temporary_number = 0


def identity(value):
    return value.st_dev, value.st_ino


def rename_noreplace(source_parent_fd, source_name, parent_fd, name):
    source_b = os.fsencode(source_name)
    name_b = os.fsencode(name)
    if system == "Darwin" and hasattr(libc, "renameatx_np"):
        result = libc.renameatx_np(
            source_parent_fd, source_b, parent_fd, name_b, 0x00000004
        )
    elif system == "Linux" and hasattr(libc, "renameat2"):
        result = libc.renameat2(source_parent_fd, source_b, parent_fd, name_b, 1)
    else:
        raise OSError(errno.ENOTSUP, "atomic no-replace rename is unavailable")
    if result != 0:
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error), name)


def capture_tree_at(parent_fd, name):
    captured = []

    def visit(owner_fd, entry_name, relative):
        value = os.stat(entry_name, dir_fd=owner_fd, follow_symlinks=False)
        captured.append((relative, identity(value), value.st_mode))
        if stat.S_ISDIR(value.st_mode):
            child_fd = os.open(entry_name, flags, dir_fd=owner_fd)
            try:
                if identity(os.fstat(child_fd)) != identity(value):
                    raise OSError(errno.ESTALE, "staged directory identity changed", entry_name)
                for child in sorted(os.listdir(child_fd)):
                    visit(child_fd, child, relative + (child,))
            finally:
                os.close(child_fd)

    visit(parent_fd, name, ())
    return captured


expected_hashes = {}


def open_directory_at(root_directory_fd, components):
    fd = os.dup(root_directory_fd)
    try:
        for component in components:
            child = os.open(component, flags, dir_fd=fd)
            os.close(fd)
            fd = child
        return fd
    except Exception:
        os.close(fd)
        raise


def copy_snapshot_directory(source_fd, parent_fd, name, relative, encountered=None):
    is_root = encountered is None
    if encountered is None:
        encountered = set()
    source_value = os.fstat(source_fd)
    if not stat.S_ISDIR(source_value.st_mode):
        raise OSError(errno.ENOTDIR, "snapshot source is not a directory", relative)
    os.mkdir(name, mode=stat.S_IMODE(source_value.st_mode), dir_fd=parent_fd)
    destination_fd = os.open(name, flags, dir_fd=parent_fd)
    try:
        for child in sorted(os.listdir(source_fd)):
            value = os.stat(child, dir_fd=source_fd, follow_symlinks=False)
            child_relative = f"{relative}/{child}"
            if stat.S_ISDIR(value.st_mode):
                child_source_fd = os.open(child, flags, dir_fd=source_fd)
                try:
                    if identity(os.fstat(child_source_fd)) != identity(value):
                        raise OSError(errno.ESTALE, "snapshot directory identity changed", child_relative)
                    copy_snapshot_directory(
                        child_source_fd, destination_fd, child, child_relative, encountered
                    )
                    if identity(os.fstat(child_source_fd)) != identity(value):
                        raise OSError(errno.ESTALE, "snapshot directory changed during copy", child_relative)
                finally:
                    os.close(child_source_fd)
                continue
            if not stat.S_ISREG(value.st_mode):
                raise OSError(errno.EPERM, "snapshot accepts only files and directories", child_relative)
            source_flags = os.O_RDONLY
            if hasattr(os, "O_NOFOLLOW"):
                source_flags |= os.O_NOFOLLOW
            child_source_fd = os.open(child, source_flags, dir_fd=source_fd)
            destination_file_fd = os.open(
                child,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL,
                stat.S_IMODE(value.st_mode),
                dir_fd=destination_fd,
            )
            digest = hashlib.sha256()
            try:
                if identity(os.fstat(child_source_fd)) != identity(value):
                    raise OSError(errno.ESTALE, "snapshot file identity changed", child_relative)
                while True:
                    block = os.read(child_source_fd, 1024 * 1024)
                    if not block:
                        break
                    digest.update(block)
                    view = memoryview(block)
                    while view:
                        written = os.write(destination_file_fd, view)
                        view = view[written:]
                if identity(os.fstat(child_source_fd)) != identity(value):
                    raise OSError(errno.ESTALE, "snapshot file changed during copy", child_relative)
            finally:
                os.close(destination_file_fd)
                os.close(child_source_fd)
            expected = expected_hashes.get(child_relative)
            if expected is None or digest.hexdigest() != expected:
                raise OSError(errno.EBADMSG, "snapshot checksum mismatch during copy", child_relative)
            encountered.add(child_relative)
    finally:
        os.close(destination_fd)
    if identity(os.fstat(source_fd)) != identity(source_value):
        raise OSError(errno.ESTALE, "snapshot source changed during copy", relative)
    expected_paths = {
        path for path in expected_hashes if path.startswith(relative + "/")
    }
    if is_root and encountered != expected_paths:
        missing = sorted(expected_paths - encountered)
        unexpected = sorted(encountered - expected_paths)
        raise OSError(
            errno.EBADMSG,
            f"snapshot source path set changed; missing={missing!r} unexpected={unexpected!r}",
            relative,
        )


def write_entry(parent_fd, name, content):
    fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600, dir_fd=parent_fd)
    try:
        data = content.encode()
        while data:
            written = os.write(fd, data)
            data = data[written:]
    finally:
        os.close(fd)


def remove_staging(parent_fd, staging_fd, staging_name, expected):
    if identity(os.fstat(staging_fd)) != expected:
        os.close(staging_fd)
        for candidate in os.listdir(parent_fd):
            value = os.stat(candidate, dir_fd=parent_fd, follow_symlinks=False)
            if identity(value) != expected:
                continue
            owned_fd = os.open(candidate, flags, dir_fd=parent_fd)
            try:
                if identity(os.fstat(owned_fd)) != expected or os.listdir(owned_fd):
                    raise OSError(errno.ESTALE, "owned staging directory changed", candidate)
            finally:
                os.close(owned_fd)
            os.rmdir(candidate, dir_fd=parent_fd)
            return
        return

    def empty(directory_fd):
        for name in os.listdir(directory_fd):
            value = os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
            if stat.S_ISDIR(value.st_mode):
                child_fd = os.open(name, flags, dir_fd=directory_fd)
                try:
                    if identity(os.fstat(child_fd)) != identity(value):
                        raise OSError(errno.ESTALE, "staging child identity changed", name)
                    empty(child_fd)
                finally:
                    os.close(child_fd)
                os.rmdir(name, dir_fd=directory_fd)
            else:
                os.unlink(name, dir_fd=directory_fd)

    empty(staging_fd)
    os.close(staging_fd)
    try:
        value = os.stat(staging_name, dir_fd=parent_fd, follow_symlinks=False)
    except FileNotFoundError:
        value = None
    if value is not None and identity(value) == expected:
        os.rmdir(staging_name, dir_fd=parent_fd)
        return
    for candidate in os.listdir(parent_fd):
        candidate_value = os.stat(candidate, dir_fd=parent_fd, follow_symlinks=False)
        if identity(candidate_value) != expected:
            continue
        owned_fd = os.open(candidate, flags, dir_fd=parent_fd)
        try:
            if identity(os.fstat(owned_fd)) != expected or os.listdir(owned_fd):
                raise OSError(errno.ESTALE, "owned staging directory changed", candidate)
        finally:
            os.close(owned_fd)
        os.rmdir(candidate, dir_fd=parent_fd)
        return
    raise OSError(errno.ESTALE, "owned staging directory was lost before cleanup", staging_name)


def content_signature(parent_fd, name):
    records = []

    def visit(owner_fd, entry_name, relative):
        value = os.stat(entry_name, dir_fd=owner_fd, follow_symlinks=False)
        kind = stat.S_IFMT(value.st_mode)
        if stat.S_ISLNK(value.st_mode):
            records.append((relative, kind, os.readlink(entry_name, dir_fd=owner_fd)))
            return
        if stat.S_ISREG(value.st_mode):
            file_flags = os.O_RDONLY
            if hasattr(os, "O_NOFOLLOW"):
                file_flags |= os.O_NOFOLLOW
            fd = os.open(entry_name, file_flags, dir_fd=owner_fd)
            try:
                if identity(os.fstat(fd)) != identity(value):
                    raise OSError(errno.ESTALE, "file identity changed during validation", entry_name)
                digest = hashlib.sha256()
                while True:
                    block = os.read(fd, 1024 * 1024)
                    if not block:
                        break
                    digest.update(block)
                if identity(os.fstat(fd)) != identity(value):
                    raise OSError(errno.ESTALE, "file identity changed during validation", entry_name)
                records.append((relative, kind, digest.hexdigest()))
            finally:
                os.close(fd)
            return
        if stat.S_ISDIR(value.st_mode):
            fd = os.open(entry_name, flags, dir_fd=owner_fd)
            try:
                if identity(os.fstat(fd)) != identity(value):
                    raise OSError(errno.ESTALE, "directory identity changed during validation", entry_name)
                records.append((relative, kind, None))
                for child in sorted(os.listdir(fd)):
                    visit(fd, child, relative + (child,))
            finally:
                os.close(fd)
            return
        records.append((relative, kind, None))

    visit(parent_fd, name, ())
    return tuple(records)


def make_owned_directory(parent_fd, name):
    global temporary_number
    while True:
        temporary_number += 1
        temporary = f".kcode-directory-{os.getpid()}-{temporary_number}"
        try:
            os.mkdir(temporary, dir_fd=parent_fd)
            break
        except FileExistsError:
            continue
    fd = None
    try:
        fd = os.open(temporary, flags, dir_fd=parent_fd)
        expected = identity(os.fstat(fd))
        rename_noreplace(parent_fd, temporary, parent_fd, name)
        created_dirs.append((parent_fd, name, expected))
        run_hook("KCODE_RESTORE_TEST_AFTER_DIRECTORY_RENAME_HOOK", name, temporary_number)
        value = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
        if identity(value) != expected:
            raise OSError(errno.ESTALE, "created directory identity changed", name)
        return fd
    except Exception:
        if fd is not None:
            os.close(fd)
        try:
            os.rmdir(temporary, dir_fd=parent_fd)
        except FileNotFoundError:
            pass
        raise


def open_directory(parts):
    key = tuple(parts)
    if key in fds:
        return fds[key]
    parent_fd = open_directory(key[:-1])
    name = key[-1]
    try:
        fd = os.open(name, flags, dir_fd=parent_fd)
    except FileNotFoundError:
        fd = make_owned_directory(parent_fd, name)
    fds[key] = fd
    return fd


def open_directory_fresh(root_fd, parts):
    fd = os.dup(root_fd)
    try:
        for component in parts:
            child = os.open(component, flags, dir_fd=fd)
            os.close(fd)
            fd = child
        return fd
    except Exception:
        os.close(fd)
        raise


def open_owned_parent(root_fd, components, provenance):
    fd = os.dup(root_fd)
    try:
        for depth, component in enumerate(components, 1):
            expected, mode = provenance[components[:depth]]
            if not stat.S_ISDIR(mode):
                raise OSError(errno.ENOTDIR, "owned path parent is not a directory", component)
            child = os.open(component, flags, dir_fd=fd)
            if identity(os.fstat(child)) != expected:
                os.close(child)
                raise OSError(errno.ESTALE, "owned path identity changed", component)
            os.close(fd)
            fd = child
        return fd
    except Exception:
        os.close(fd)
        raise


def quarantine_name():
    return f".kcode-rollback-{os.getpid()}-{secrets.token_hex(12)}"


def quarantine(parent_fd, name):
    temporary = quarantine_name()
    try:
        rename_noreplace(parent_fd, name, parent_fd, temporary)
    except FileNotFoundError:
        return None
    return temporary


def restore_quarantine(parent_fd, temporary, name):
    try:
        rename_noreplace(parent_fd, temporary, parent_fd, name)
        return
    except FileNotFoundError:
        return
    except FileExistsError as error:
        recovery = f"kcode-restore-recovery-{os.getpid()}-{secrets.token_hex(12)}"
        rename_noreplace(parent_fd, temporary, parent_fd, recovery)
        raise RuntimeError(
            f"safe rollback was impossible because {name!r} was recreated; "
            f"preserved displaced data as {recovery!r}"
        ) from error


def remove_owned_entry(parent_fd, name, expected, mode):
    temporary = quarantine(parent_fd, name)
    if temporary is None:
        return
    try:
        value = os.stat(temporary, dir_fd=parent_fd, follow_symlinks=False)
        if identity(value) != expected:
            restore_quarantine(parent_fd, temporary, name)
            return
        if stat.S_ISDIR(mode):
            os.rmdir(temporary, dir_fd=parent_fd)
        else:
            os.unlink(temporary, dir_fd=parent_fd)
    except OSError:
        restore_quarantine(parent_fd, temporary, name)


def remove_owned_path(parent_fd, name, captured):
    provenance = {components: (expected, mode) for components, expected, mode in captured}
    root_expected, root_mode = provenance[()]
    temporary = quarantine(parent_fd, name)
    if temporary is None:
        return
    try:
        value = os.stat(temporary, dir_fd=parent_fd, follow_symlinks=False)
        if identity(value) != root_expected:
            restore_quarantine(parent_fd, temporary, name)
            return
        if not stat.S_ISDIR(root_mode):
            os.unlink(temporary, dir_fd=parent_fd)
            return
        root_fd = os.open(temporary, flags, dir_fd=parent_fd)
        try:
            if identity(os.fstat(root_fd)) != root_expected:
                restore_quarantine(parent_fd, temporary, name)
                return
            entries = sorted(
                (item for item in captured if item[0]),
                key=lambda item: (len(item[0]), item[0]),
                reverse=True,
            )
            for components, expected, mode in entries:
                try:
                    owner_fd = open_owned_parent(root_fd, components[:-1], provenance)
                    try:
                        remove_owned_entry(owner_fd, components[-1], expected, mode)
                    finally:
                        os.close(owner_fd)
                except OSError:
                    continue
        finally:
            os.close(root_fd)
        try:
            os.rmdir(temporary, dir_fd=parent_fd)
        except OSError:
            run_hook("KCODE_RESTORE_TEST_BEFORE_QUARANTINE_RESTORE_HOOK", name, 0)
            restore_quarantine(parent_fd, temporary, name)
    except OSError:
        restore_quarantine(parent_fd, temporary, name)


def rollback():
    failures = []
    for parent_fd, name, captured in reversed(created_paths):
        try:
            remove_owned_path(parent_fd, name, captured)
        except Exception as error:
            failures.append(error)
    for parent_fd, name, expected in reversed(created_dirs):
        try:
            remove_owned_entry(parent_fd, name, expected, stat.S_IFDIR)
        except Exception as error:
            failures.append(error)
    return failures


def run_hook(variable, destination, number):
    hook = os.environ.get(variable)
    if hook:
        subprocess.run((hook, destination, str(number)), check=True)


root_fd = os.open(os.path.sep, flags)
fds[()] = root_fd
root_parts = tuple(part for part in root.split(os.path.sep) if part)
project_fd = open_directory_at(root_fd, root_parts)
checksum_flags = os.O_RDONLY
if hasattr(os, "O_NOFOLLOW"):
    checksum_flags |= os.O_NOFOLLOW
checksums_fd = os.open(
    os.path.relpath(checksums_path, root), checksum_flags, dir_fd=project_fd
)
checksums_value = os.fstat(checksums_fd)
run_hook("KCODE_RESTORE_TEST_AFTER_CONTROL_OPEN_HOOK", checksums_path, 1)
with os.fdopen(checksums_fd, "rb", closefd=True) as checksum_file:
    checksum_bytes = checksum_file.read()
    if identity(os.fstat(checksum_file.fileno())) != identity(checksums_value):
        raise OSError(errno.ESTALE, "checksum manifest changed while reading")
if hashlib.sha256(checksum_bytes).hexdigest() != checksums_digest:
    raise OSError(errno.EBADMSG, "checksum manifest bytes changed after verification")
for row in checksum_bytes.decode("utf-8").splitlines():
    digest, relative = row.split(None, 1)
    if relative in expected_hashes:
        raise OSError(errno.EBADMSG, "duplicate checksum manifest path", relative)
    expected_hashes[relative] = digest
validations = []
staging_fd = None
staging_parent_fd = None
staging_name = None
staging_expected = None
try:
    home_parts = tuple(part for part in home.split(os.path.sep) if part)
    staging_parent_fd = os.dup(root_fd)
    existing_depth = 0
    for component in home_parts[:-1]:
        try:
            child_fd = os.open(component, flags, dir_fd=staging_parent_fd)
        except FileNotFoundError:
            break
        os.close(staging_parent_fd)
        staging_parent_fd = child_fd
        existing_depth += 1
    run_hook("KCODE_RESTORE_TEST_AFTER_STAGING_PARENT_OPEN_HOOK", home, existing_depth)
    staging_name = f".kcode-restore-{os.getpid()}-{secrets.token_hex(12)}"
    os.mkdir(staging_name, mode=0o700, dir_fd=staging_parent_fd)
    staging_fd = os.open(staging_name, flags, dir_fd=staging_parent_fd)
    staging_expected = identity(os.fstat(staging_fd))
    staging_path = os.path.join(os.path.sep, *home_parts[:existing_depth], staging_name)
    run_hook("KCODE_RESTORE_TEST_AFTER_STAGING_MKDIR_HOOK", staging_path, 0)

    rows = []
    threejs = {"claude": [], "codex": []}
    manifest_fd = os.open(os.path.relpath(manifest, root), checksum_flags, dir_fd=project_fd)
    manifest_value = os.fstat(manifest_fd)
    run_hook("KCODE_RESTORE_TEST_AFTER_CONTROL_OPEN_HOOK", manifest, 2)
    with os.fdopen(manifest_fd, "rb", closefd=True) as manifest_file:
        manifest_bytes = manifest_file.read()
        if identity(os.fstat(manifest_file.fileno())) != identity(manifest_value):
            raise OSError(errno.ESTALE, "restore manifest changed while reading")
    if hashlib.sha256(manifest_bytes).hexdigest() != manifest_digest:
        raise OSError(errno.EBADMSG, "restore manifest bytes changed after verification")
    for row in manifest_bytes.decode("utf-8").splitlines():
            if not row.strip() or row.startswith("#"):
                continue
            source, target, name = row.split("\t")
            target_root = {
                "generic": ".agents/skills",
                "claude": ".claude/skills",
                "codex": ".codex/skills",
                "grok": ".grok/skills",
            }[target]
            destination = os.path.join(home, target_root, name)
            staged_name = f"skill-{len(rows) + 1}"
            source_parts = tuple(part for part in source.split(os.path.sep) if part)
            source_fd = open_directory_at(project_fd, source_parts)
            try:
                run_hook(
                    "KCODE_RESTORE_TEST_AFTER_SOURCE_OPEN_HOOK", source, len(rows) + 1
                )
                copy_snapshot_directory(source_fd, staging_fd, staged_name, source)
            finally:
                os.close(source_fd)
            rows.append((staged_name, destination))
            if target in threejs and source.startswith("skill-snapshot/vendor/threejs-game-skills/"):
                threejs[target].append(name)
    for target in ("claude", "codex"):
        if not threejs[target]:
            continue
        staged_name = f"marker-{target}"
        write_entry(staging_fd, staged_name, "\n".join(sorted(threejs[target])) + "\n")
        rows.append((staged_name, os.path.join(home, f".{target}/skills/.threejs-game-skills-managed")))

    hook = os.environ.get("KCODE_RESTORE_TEST_HOOK")
    if hook:
        subprocess.run((hook, home), check=True)
    open_directory(home_parts)
    for number, (staged_name, destination) in enumerate(rows, 1):
        relative = os.path.relpath(destination, home)
        if relative == os.pardir or relative.startswith(os.pardir + os.path.sep):
            raise OSError(errno.EPERM, "restore destination escapes requested home", destination)
        parts = tuple(part for part in relative.split(os.path.sep) if part)
        parent_fd = open_directory(home_parts + parts[:-1])
        name = parts[-1]
        expected_signature = content_signature(staging_fd, staged_name)
        try:
            os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
        except FileNotFoundError:
            captured = capture_tree_at(staging_fd, staged_name)
            rename_noreplace(staging_fd, staged_name, parent_fd, name)
            created_paths.append((parent_fd, name, captured))
            run_hook("KCODE_RESTORE_TEST_AFTER_RENAME_HOOK", destination, number)
            value = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
            if identity(value) != captured[0][1]:
                raise OSError(errno.ESTALE, "promoted path identity changed", destination)
            run_hook("KCODE_RESTORE_TEST_AFTER_PROMOTE_HOOK", destination, number)
            fail_after = os.environ.get("KCODE_RESTORE_TEST_FAIL_AFTER")
            if fail_after and number == int(fail_after):
                raise OSError(errno.EIO, "injected restore promotion failure", destination)
        else:
            if content_signature(parent_fd, name) != expected_signature:
                raise OSError(errno.ESTALE, "existing destination changed after preflight", destination)
        validations.append((parent_fd, name, expected_signature, destination))
    run_hook("KCODE_RESTORE_TEST_BEFORE_FINAL_VALIDATION_HOOK", home, len(validations))
    for _, name, expected_signature, destination in validations:
        relative = os.path.relpath(destination, home)
        parts = tuple(part for part in relative.split(os.path.sep) if part)
        parent_fd = open_directory_fresh(root_fd, home_parts + parts[:-1])
        try:
            if content_signature(parent_fd, name) != expected_signature:
                raise OSError(errno.ESTALE, "restore destination changed before commit", destination)
        finally:
            os.close(parent_fd)
    run_hook("KCODE_RESTORE_TEST_BEFORE_STAGING_CLEANUP_HOOK", staging_path, len(validations))
except Exception as original:
    failures = rollback()
    if failures:
        details = "; ".join(str(error) for error in failures)
        raise RuntimeError(f"restore failed and rollback was incomplete: {details}") from original
    raise
finally:
    cleanup_error = None
    if staging_fd is not None:
        try:
            remove_staging(staging_parent_fd, staging_fd, staging_name, staging_expected)
        except Exception as error:
            cleanup_error = error
    if staging_parent_fd is not None:
        os.close(staging_parent_fd)
    os.close(project_fd)
    if cleanup_error is not None:
        failures = rollback()
        if failures:
            details = "; ".join(str(error) for error in failures)
            raise RuntimeError(
                f"staging cleanup failed and rollback was incomplete: {details}"
            ) from cleanup_error
        raise cleanup_error
    for fd in reversed(tuple(fds.values())):
        os.close(fd)
PY
}

restore_home() {
  local home=$1 requested_home source target name directory link
  local manifest_digest checksums_digest
  local count=0
  [ -n "$home" ] || fail 'restore requires a non-empty --home path'
  case "$home" in
    *$'\t'*|*$'\n'*) fail 'restore home must not contain tabs or newlines' ;;
  esac
  link=$(reject_requested_home_symlinks "$home") \
    || fail "restore home contains a symlinked component: $link"
  requested_home=$(python3 - "$home" <<'PY'
import os
import sys

print(os.path.abspath(sys.argv[1]))
PY
)
  home=$(absolute_path "$requested_home")
  verify_snapshot >/dev/null
  manifest_digest=$(file_sha256 "$RESTORE_MANIFEST")
  checksums_digest=$(file_sha256 "$CHECKSUMS")
  preflight_parent "$home"

  while IFS=$'\t' read -r source target name; do
    directory=$(target_dir "$home" "$target")
    preflight_skill "$home" "$ROOT/$source" "$directory/$name"
    count=$((count + 1))
  done < <(manifest_rows)
  preflight_threejs_marker "$home" claude
  preflight_threejs_marker "$home" codex

  [ "$(file_sha256 "$RESTORE_MANIFEST")" = "$manifest_digest" ] \
    || fail 'restore manifest changed during preflight'
  [ "$(file_sha256 "$CHECKSUMS")" = "$checksums_digest" ] \
    || fail 'checksum manifest changed during preflight'
  promote_restore_plan "$home" "$manifest_digest" "$checksums_digest"
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
    expected=$(threejs_marker_content "$target")
    cmp -s "$directory/.threejs-game-skills-managed" <(printf '%s\n' "$expected") \
      || fail "Three.js manager marker differs or is missing in $directory"
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
