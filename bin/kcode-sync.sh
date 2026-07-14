#!/usr/bin/env bash
# kcode-sync.sh - mirror the live Firstmate operating home into korallis/k-code.
#
# The sync mirrors Firstmate-derived tooling plus this fleet's tracked config and
# memory, verifies that the separate skill snapshot still covers every active
# skill root, removes all project paths from the destination index, and commits
# and pushes only when the result changed.
#
# Product checkouts, volatile runtime, and secrets are never copied.
# Existing ignored product checkouts in the destination are never deleted.
#
# k-code-owned surfaces are not overwritten:
#   README.md, CONTRIBUTING.md, docs/scripts.md, .gitattributes, .gitignore,
#   .no-mistakes.yaml, .pi/settings.json, config/kcode-data-policy.tsv,
#   .github/workflows/, assets/kcode/,
#   docs/assets/, skill-snapshot/, bin/kcode-*.sh, and tests/kcode-*.test.sh.
#
# Usage: bin/kcode-sync.sh [<message>]
#   Run from the live Firstmate home.
#   KCODE_DIR defaults to ../k-code next to FM_HOME.
#   KCODE_SKILL_USER_HOME overrides the user home examined for active skills.
#   KCODE_SYNC_DRY_RUN=1 stages the result without committing or pushing.
set -euo pipefail

FM_HOME="${FM_HOME:-$(git rev-parse --show-toplevel)}"
KCODE_DIR="${KCODE_DIR:-$(dirname "$FM_HOME")/k-code}"
SKILL_USER_HOME="${KCODE_SKILL_USER_HOME:-$HOME}"
DRY_RUN="${KCODE_SYNC_DRY_RUN:-0}"
MSG="${1:-sync: mirror firstmate operating home $(date -u +%Y-%m-%dT%H:%MZ)}"
DATA_POLICY="$KCODE_DIR/config/kcode-data-policy.tsv"

[ -f "$DATA_POLICY" ] || {
  printf 'kcode-sync: missing data policy at %s\n' "$DATA_POLICY" >&2
  exit 1
}
data_directories=()
data_extensions=()
while IFS=$'\t' read -r kind value; do
  case "$kind" in
    directory) data_directories+=("$value") ;;
    extension) data_extensions+=("$value") ;;
    \#*|'') ;;
    *) printf 'kcode-sync: invalid data policy row: %s\t%s\n' "$kind" "$value" >&2; exit 1 ;;
  esac
done < "$DATA_POLICY"
data_excludes=()
for value in "${data_directories[@]}"; do
  data_excludes+=("--exclude=data/**/$value/")
done
for value in "${data_extensions[@]}"; do
  data_excludes+=("--exclude=data/**/*.$value")
done

[ -d "$KCODE_DIR/.git" ] || [ -f "$KCODE_DIR/.git" ] || {
  printf 'kcode-sync: no k-code checkout at %s (set KCODE_DIR)\n' "$KCODE_DIR" >&2
  exit 1
}
[ -x "$KCODE_DIR/bin/kcode-skills.sh" ] || {
  printf 'kcode-sync: missing executable k-code skill manager at %s\n' \
    "$KCODE_DIR/bin/kcode-skills.sh" >&2
  exit 1
}

# Mirror the live working tree, not only committed HEAD.
# Excluding projects/ prevents source clones from entering the destination, while
# the explicit index cleanup below removes any stale tracked destination paths.
# Exclude both .git/ and .git because linked worktrees use a gitfile.
rsync -a --delete \
  --exclude='.git/' \
  --exclude='.git' \
  --exclude='.gitmodules' \
  --exclude='.gitattributes' \
  --exclude='.gitignore' \
  --exclude='.no-mistakes.yaml' \
  --exclude='.pi/settings.json' \
  --exclude='config/kcode-data-policy.tsv' \
  --exclude='README.md' \
  --exclude='CONTRIBUTING.md' \
  --exclude='docs/scripts.md' \
  --exclude='.github/workflows/' \
  --exclude='assets/kcode/' \
  --exclude='docs/assets/' \
  --exclude='skill-snapshot/' \
  --exclude='bin/kcode-*.sh' \
  --exclude='tests/kcode-*.test.sh' \
  --exclude='projects/' \
  --exclude='state/' \
  --exclude='.no-mistakes/' \
  --exclude='.lavish/' \
  --exclude='.pi/npm/' \
  --exclude='.pi/git/' \
  --exclude='.pi/claude-bridge.json' \
  --exclude='.pi/cc-cli-logs/' \
  --exclude='.pi/sessions/' \
  --exclude='node_modules/' \
  --exclude='.DS_Store' \
  --exclude='.env' \
  --exclude='*.key' \
  --exclude='*credential*' \
  --exclude='config/x-mode.env' \
  --exclude='config/cmux-socket-password' \
  "${data_excludes[@]}" \
  "$FM_HOME"/ "$KCODE_DIR"/

if [ -d "$KCODE_DIR/data" ]; then
  for value in "${data_extensions[@]}"; do
    find "$KCODE_DIR/data" -type f -iname "*.$value" -delete
  done
  for value in "${data_directories[@]}"; do
    find "$KCODE_DIR/data" -depth -type d -name "$value" -exec rm -rf {} +
  done
fi
rm -f "$KCODE_DIR/.github/WORKFLOWS-NOTE.md"

# k-code tracks fleet config and memory, but never local products or runtime
# credentials. This heredoc is the single owner of the fork's ignore contract.
cat > "$KCODE_DIR/.gitignore" <<'GI'
projects/
state/
.no-mistakes/
.lavish/
.fm-secondmate-home
.fm-grok-turnend
.env
*.key
*credential*
!skill-snapshot/vendor/**
config/x-mode.env
config/cmux-socket-password
.pi/npm/
.pi/git/
.pi/claude-bridge.json
.pi/cc-cli-logs/
.pi/sessions/
.DS_Store
__pycache__/
*.pyc
*.log
GI
for value in "${data_extensions[@]}"; do
  printf 'data/**/*.%s\n' "$value" >> "$KCODE_DIR/.gitignore"
done
for value in "${data_directories[@]}"; do
  printf 'data/**/%s/\n' "$value" >> "$KCODE_DIR/.gitignore"
done

# Excluding a source path does not remove an old destination index entry.
# Remove only index records so an ignored local product checkout remains intact.
rm -f "$KCODE_DIR/.gitmodules"
tracked_projects=$(git -C "$KCODE_DIR" ls-files -- projects)
if [ -n "$tracked_projects" ]; then
  git -C "$KCODE_DIR" rm -r --cached --ignore-unmatch -- projects >/dev/null
fi

# The snapshot is k-code-owned and deduplicated, so sync validates it against
# both the mirrored project roots and every active user/harness skill root.
# Any new, removed, changed, or unlicensed skill blocks a partial sync instead
# of being silently omitted or copied without review.
"$KCODE_DIR/bin/kcode-skills.sh" verify
"$KCODE_DIR/bin/kcode-skills.sh" verify-live \
  --from-home "$FM_HOME" --user-home "$SKILL_USER_HOME"

git -C "$KCODE_DIR" add -A
"$KCODE_DIR/bin/kcode-integrity.sh"

tracked_projects=$(git -C "$KCODE_DIR" ls-files -- projects)
if [ -n "$tracked_projects" ]; then
  printf 'kcode-sync: refusing to continue with tracked projects/ entries\n' >&2
  exit 1
fi
if git -C "$KCODE_DIR" ls-files --error-unmatch .gitmodules >/dev/null 2>&1; then
  printf 'kcode-sync: refusing to continue with tracked .gitmodules metadata\n' >&2
  exit 1
fi
gitlinks=$(git -C "$KCODE_DIR" ls-files -s | awk '$1 == "160000" {print $4}')
if [ -n "$gitlinks" ]; then
  printf 'kcode-sync: refusing to continue with tracked gitlinks:\n%s\n' "$gitlinks" >&2
  exit 1
fi

if git -C "$KCODE_DIR" diff --cached --quiet; then
  printf 'kcode-sync: nothing to sync.\n'
elif [ "$DRY_RUN" = 1 ]; then
  printf 'kcode-sync: dry run staged changes without commit or push.\n'
else
  git -C "$KCODE_DIR" commit -q -m "$MSG"
  git -C "$KCODE_DIR" push -q
  printf 'kcode-sync: pushed to k-code.\n'
fi
