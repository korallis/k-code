#!/usr/bin/env bash
# kcode-sync.sh - mirror this firstmate operating home into the korallis/k-code fork.
#
# k-code is the captain's Firstmate fork: a first-class public repo that carries
# this fleet's adjustments, routing, durable memory, dashboard tooling, and
# project submodules. It stays synchronized from the live operating home.
#
# Re-mirrors firstmate's working tree plus this fleet's config/ and data/,
# refreshes the project submodule pointers, commits, and pushes to k-code.
# Secrets are never copied (keys live in 1Password; env files are pulled at
# task time). Volatile runtime (state/, .no-mistakes/, .lavish/) is excluded.
#
# k-code-owned surfaces (not overwritten by sync):
#   README.md, .gitignore, .github/workflows/, assets/kcode/, docs/assets/
#
# Usage: bin/kcode-sync.sh [<message>]
#   Run from the firstmate home. Requires a checkout of korallis/k-code and gh auth.
#   Set KCODE_DIR to point at your k-code checkout (default: ../k-code next to FM_HOME).
set -euo pipefail

FM_HOME="${FM_HOME:-$(git rev-parse --show-toplevel)}"
KCODE_DIR="${KCODE_DIR:-$(dirname "$FM_HOME")/k-code}"
MSG="${1:-sync: mirror firstmate operating home $(date -u +%Y-%m-%dT%H:%MZ)}"

[ -d "$KCODE_DIR/.git" ] || [ -f "$KCODE_DIR/.git" ] || {
  echo "kcode-sync: no k-code checkout at $KCODE_DIR (set KCODE_DIR)" >&2
  exit 1
}

# 1. Mirror firstmate's WORKING TREE (not just committed HEAD) so uncommitted
# tooling and in-progress changes sync too. --delete prunes files removed from
# firstmate, while k-code-owned presentation/CI paths are excluded so they
# survive. Submodule clones, volatile runtime, and secrets are excluded;
# k-code's .gitignore is the second gate.
# Note: exclude both .git/ and .git (worktrees use a gitfile) so --delete never
# removes the checkout's git link.
rsync -a --delete \
  --exclude='.git/' \
  --exclude='.git' \
  --exclude='.gitmodules' \
  --exclude='.gitignore' \
  --exclude='README.md' \
  --exclude='.github/workflows/' \
  --exclude='assets/kcode/' \
  --exclude='docs/assets/' \
  --exclude='projects/' \
  --exclude='state/' \
  --exclude='.no-mistakes/' \
  --exclude='.lavish/' \
  --exclude='node_modules/' \
  --exclude='.DS_Store' \
  --exclude='.env' \
  --exclude='*.key' \
  --exclude='*credential*' \
  --exclude='config/x-mode.env' \
  --exclude='config/cmux-socket-password' \
  --exclude='data/kcode-rebuild-g7/' \
  "$FM_HOME"/ "$KCODE_DIR"/

rm -f "$KCODE_DIR/.github/WORKFLOWS-NOTE.md" 2>/dev/null || true

# 2. Restore the k-code-specific .gitignore (firstmate's would re-hide config/data).
cat > "$KCODE_DIR/.gitignore" <<'GI'
state/
.no-mistakes/
.lavish/
.fm-secondmate-home
.fm-grok-turnend
.env
*.key
*credential*
config/x-mode.env
config/cmux-socket-password
.DS_Store
__pycache__/
*.pyc
*.log
GI

# 3. Advance project submodule pointers to their latest pushed commits.
git -C "$KCODE_DIR" submodule update --remote --quiet 2>/dev/null || true

# 4. Commit and push if anything changed.
git -C "$KCODE_DIR" add -A
if git -C "$KCODE_DIR" diff --cached --quiet; then
  echo "kcode-sync: nothing to sync."
else
  git -C "$KCODE_DIR" commit -q -m "$MSG"
  git -C "$KCODE_DIR" push -q
  echo "kcode-sync: pushed to k-code."
fi
