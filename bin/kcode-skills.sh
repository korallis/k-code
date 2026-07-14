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

promote_restore_plan() {
  local home=$1 plan=$2
  python3 - "$home" "$plan" <<'PY'
import ctypes
import errno
import hashlib
import os
import platform
import secrets
import stat
import subprocess
import sys

home, plan = map(os.path.abspath, sys.argv[1:])
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


def capture_tree(path):
    captured = []
    root = os.lstat(path)
    captured.append(((), identity(root), root.st_mode))
    if stat.S_ISDIR(root.st_mode):
        for directory, names, files in os.walk(path, topdown=True, followlinks=False):
            names.sort()
            files.sort()
            relative_directory = os.path.relpath(directory, path)
            prefix = () if relative_directory == "." else tuple(relative_directory.split(os.path.sep))
            for name in names + files:
                value = os.lstat(os.path.join(directory, name))
                captured.append((prefix + (name,), identity(value), value.st_mode))
    return captured


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
validations = []
try:
    home_parts = tuple(part for part in home.split(os.path.sep) if part)
    open_directory(home_parts)
    with open(plan, encoding="utf-8") as rows:
        for number, row in enumerate(rows, 1):
            source, destination = row.rstrip("\n").split("\t", 1)
            relative = os.path.relpath(destination, home)
            if relative == os.pardir or relative.startswith(os.pardir + os.path.sep):
                raise OSError(errno.EPERM, "restore destination escapes requested home", destination)
            parts = tuple(part for part in relative.split(os.path.sep) if part)
            parent_fd = open_directory(home_parts + parts[:-1])
            name = parts[-1]
            source_parent = os.open(os.path.dirname(source), flags)
            try:
                expected_signature = content_signature(source_parent, os.path.basename(source))
            finally:
                os.close(source_parent)
            try:
                os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
            except FileNotFoundError:
                captured = capture_tree(source)
                source_parent = os.open(os.path.dirname(source), flags)
                try:
                    rename_noreplace(source_parent, os.path.basename(source), parent_fd, name)
                finally:
                    os.close(source_parent)
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
except Exception as original:
    failures = rollback()
    if failures:
        details = "; ".join(str(error) for error in failures)
        raise RuntimeError(f"restore failed and rollback was incomplete: {details}") from original
    raise
finally:
    for fd in reversed(tuple(fds.values())):
        os.close(fd)
PY
}

restore_home() {
  local home=$1 requested_home source target name directory destination expected stage link
  local count=0 transaction transaction_parent plan transaction_active=0
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
  preflight_parent "$home"

  while IFS=$'\t' read -r source target name; do
    directory=$(target_dir "$home" "$target")
    preflight_skill "$home" "$ROOT/$source" "$directory/$name"
    count=$((count + 1))
  done < <(manifest_rows)
  preflight_threejs_marker "$home" claude
  preflight_threejs_marker "$home" codex

  transaction_parent=$(dirname "$home")
  while [ ! -d "$transaction_parent" ]; do
    transaction_parent=$(dirname "$transaction_parent")
  done
  transaction=$(mktemp -d "$transaction_parent/.kcode-restore.XXXXXX")
  plan="$transaction/plan.tsv"
  : > "$plan"
  transaction_active=1
  trap 'if [ "$transaction_active" -eq 1 ]; then rm -rf -- "$transaction"; fi' EXIT

  count=0
  while IFS=$'\t' read -r source target name; do
    count=$((count + 1))
    directory=$(target_dir "$home" "$target")
    destination="$directory/$name"
    stage="$transaction/skill-$count"
    cp -R "$ROOT/$source" "$stage"
    printf '%s\t%s\n' "$stage" "$destination" >> "$plan"
  done < <(manifest_rows)

  for target in claude codex; do
    expected=$(threejs_marker_content "$target")
    [ -n "$expected" ] || continue
    directory=$(target_dir "$home" "$target")
    destination="$directory/.threejs-game-skills-managed"
    stage="$transaction/marker-$target"
    printf '%s\n' "$expected" > "$stage"
    printf '%s\t%s\n' "$stage" "$destination" >> "$plan"
  done

  if [ -n "${KCODE_RESTORE_TEST_HOOK:-}" ]; then
    "$KCODE_RESTORE_TEST_HOOK" "$home"
  fi
  promote_restore_plan "$home" "$plan"

  transaction_active=0
  trap - EXIT
  rm -rf -- "$transaction"
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
