#!/usr/bin/env bash
# Regression coverage for k-code synchronization and product-repository exclusion.
set -euo pipefail

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SYNC="$ROOT/bin/kcode-sync.sh"

build_fixture() {
  local temp=$1 live=$2 destination=$3 product=$4
  fm_git_identity
  fm_git_init_commit "$live"
  mkdir -p \
    "$live/bin" \
    "$live/.agents/skills/live-skill" \
    "$live/skills/public-skill" \
    "$live/.github/workflows" \
    "$live/.pi/npm" \
    "$live/config" \
    "$live/data/ordinary-task/preview" \
    "$live/data/ordinary-task/screenshots" \
    "$live/projects/source-product" \
    "$live/state"
  printf 'live tool\n' > "$live/bin/live-tool.sh"
  printf 'must not overwrite fork sync\n' > "$live/bin/kcode-sync.sh"
  printf '%s\n' '---' 'name: live-skill' 'description: fixture' '---' \
    > "$live/.agents/skills/live-skill/SKILL.md"
  printf '%s\n' '---' 'name: public-skill' 'description: fixture' '---' \
    > "$live/skills/public-skill/SKILL.md"
  printf 'upstream workflow\n' > "$live/.github/workflows/live.yml"
  printf '{"packages":["npm:unreviewed"]}\n' > "$live/.pi/settings.json"
  printf 'package cache\n' > "$live/.pi/npm/package-lock.json"
  printf '{}\n' > "$live/config/crew-dispatch.json"
  printf 'upstream data policy\n' > "$live/config/kcode-data-policy.tsv"
  printf 'durable\n' > "$live/data/backlog.md"
  printf 'safe durable task memory\n' > "$live/data/ordinary-task/brief.md"
  printf 'archived git history\n' > "$live/data/ordinary-task/history.bundle"
  printf 'generated preview\n' > "$live/data/ordinary-task/preview/index.html"
  printf 'generated render\n' > "$live/data/ordinary-task/screenshots/frame.png"
  printf 'generated image extension\n' > "$live/data/ordinary-task/loose.WEBP"
  printf 'source product\n' > "$live/projects/source-product/only-source.txt"
  printf 'runtime\n' > "$live/state/task.status"
  printf 'live README\n' > "$live/README.md"
  printf 'upstream contributing\n' > "$live/CONTRIBUTING.md"
  mkdir -p "$live/docs"
  printf 'upstream scripts guide\n' > "$live/docs/scripts.md"
  printf 'upstream attributes\n' > "$live/.gitattributes"
  printf 'upstream validation\n' > "$live/.no-mistakes.yaml"
  git -C "$live" add -A
  git -C "$live" commit -qm 'live fixture'

  fm_git_init_commit "$product"
  fm_git_init_commit "$destination"

  mkdir -p \
    "$destination/bin" \
    "$destination/tests" \
    "$destination/.github/workflows" \
    "$destination/.pi" \
    "$destination/assets/kcode" \
    "$destination/docs/assets" \
    "$destination/skill-snapshot" \
    "$destination/projects/legacy"
  printf 'fork README\n' > "$destination/README.md"
  printf 'fork contributing\n' > "$destination/CONTRIBUTING.md"
  printf 'fork scripts guide\n' > "$destination/docs/scripts.md"
  printf 'fork attributes\n' > "$destination/.gitattributes"
  printf 'fork validation\n' > "$destination/.no-mistakes.yaml"
  mkdir -p "$destination/config"
  cp "$ROOT/config/kcode-data-policy.tsv" "$destination/config/kcode-data-policy.tsv"
  printf '{"packages":["npm:pi-xai-oauth@1.3.3","npm:pi-claude-bridge@0.6.2"]}\n' \
    > "$destination/.pi/settings.json"
  printf 'old ignore\n' > "$destination/.gitignore"
  printf 'fork integrity\n' > "$destination/.github/workflows/integrity.yml"
  printf 'fork art\n' > "$destination/assets/kcode/sentinel.txt"
  printf 'fork docs art\n' > "$destination/docs/assets/sentinel.txt"
  printf 'fork skill snapshot\n' > "$destination/skill-snapshot/sentinel.txt"
  printf 'protected sync\n' > "$destination/bin/kcode-sync.sh"
  printf 'protected test\n' > "$destination/tests/kcode-sync.test.sh"
  printf 'legacy local checkout\n' > "$destination/projects/legacy/local.txt"
  mkdir -p "$destination/data/ordinary-task/render"
  printf 'stale render\n' > "$destination/data/ordinary-task/render/frame.html"
  printf 'stale image\n' > "$destination/data/ordinary-task/stale-image.JPEG"
  printf 'stale bundle\n' > "$destination/data/ordinary-task/stale-history.bundle"
  cat > "$destination/bin/kcode-skills.sh" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$KCODE_SKILL_LOG"
SH
  cat > "$destination/bin/kcode-integrity.sh" <<'SH'
#!/usr/bin/env bash
printf '%s\n' integrity >> "$KCODE_SKILL_LOG"
SH
  chmod +x "$destination/bin/kcode-skills.sh" "$destination/bin/kcode-integrity.sh"
  git -C "$destination" add -A
  git -C "$destination" commit -qm 'fork fixture'

  git -c protocol.file.allow=always -C "$destination" submodule add -q \
    "$product" projects/product
  git -C "$destination" commit -qam 'add stale product gitlink'

  mkdir -p "$temp/user"
}

test_sync_preserves_local_products_but_removes_tracking() {
  local temp live destination product log out before after gitlinks
  temp=$(fm_test_tmproot kcode-sync)
  live="$temp/live"
  destination="$temp/k-code"
  product="$temp/product"
  log="$temp/skill-manager.log"
  build_fixture "$temp" "$live" "$destination" "$product"

  before=$(git -C "$destination" rev-parse HEAD)
  out=$(FM_HOME="$live" \
    KCODE_DIR="$destination" \
    KCODE_SKILL_USER_HOME="$temp/user" \
    KCODE_SKILL_LOG="$log" \
    KCODE_SYNC_DRY_RUN=1 \
    "$SYNC" 'fixture sync')
  after=$(git -C "$destination" rev-parse HEAD)

  assert_contains "$out" 'dry run staged changes without commit or push' \
    'dry-run sync did not stop before commit and push'
  [ "$before" = "$after" ] || fail 'dry-run sync created a commit'
  [ "$(cat "$destination/README.md")" = 'fork README' ] || fail 'sync overwrote fork README'
  [ "$(cat "$destination/CONTRIBUTING.md")" = 'fork contributing' ] \
    || fail 'sync overwrote fork contributing guidance'
  [ "$(cat "$destination/docs/scripts.md")" = 'fork scripts guide' ] \
    || fail 'sync overwrote fork scripts guidance'
  [ "$(cat "$destination/.gitattributes")" = 'fork attributes' ] \
    || fail 'sync overwrote fork vendored-source attributes'
  [ "$(cat "$destination/.no-mistakes.yaml")" = 'fork validation' ] \
    || fail 'sync overwrote fork validation posture'
  assert_contains "$(cat "$destination/.pi/settings.json")" 'npm:pi-xai-oauth@1.3.3' \
    'sync overwrote the fork-owned Pi package declarations'
  cmp -s "$destination/config/kcode-data-policy.tsv" "$ROOT/config/kcode-data-policy.tsv" \
    || fail 'sync overwrote the fork-owned data policy'
  assert_absent "$destination/.pi/npm" 'sync copied the live Pi package store'
  [ "$(cat "$destination/bin/kcode-sync.sh")" = 'protected sync' ] \
    || fail 'sync overwrote its protected fork script'
  assert_present "$destination/.github/workflows/integrity.yml" 'sync removed fork integrity CI'
  assert_absent "$destination/.github/workflows/live.yml" 'sync imported an upstream workflow'
  assert_present "$destination/assets/kcode/sentinel.txt" 'sync removed fork artwork'
  assert_present "$destination/docs/assets/sentinel.txt" 'sync removed fork docs artwork'
  assert_present "$destination/skill-snapshot/sentinel.txt" 'sync removed the skill snapshot'
  assert_present "$destination/bin/live-tool.sh" 'sync did not mirror live Firstmate tooling'
  assert_present "$destination/.agents/skills/live-skill/SKILL.md" 'sync did not mirror project skills'
  assert_present "$destination/skills/public-skill/SKILL.md" 'sync did not mirror public skills'
  assert_absent "$destination/state/task.status" 'sync copied volatile runtime state'
  assert_absent "$destination/projects/source-product" 'sync copied a source product checkout'
  assert_present "$destination/data/ordinary-task/brief.md" 'sync dropped safe durable task memory'
  assert_absent "$destination/data/ordinary-task/history.bundle" 'sync copied an archived Git bundle'
  assert_absent "$destination/data/ordinary-task/preview" 'sync copied a singular generated preview directory'
  assert_absent "$destination/data/ordinary-task/screenshots" 'sync copied generated renders'
  assert_absent "$destination/data/ordinary-task/loose.WEBP" 'sync copied a generated image extension'
  assert_absent "$destination/data/ordinary-task/stale-history.bundle" 'sync retained a stale archived Git bundle'
  assert_absent "$destination/data/ordinary-task/render" 'sync retained a singular generated render directory'
  assert_absent "$destination/data/ordinary-task/stale-image.JPEG" 'sync retained a stale generated image extension'
  assert_not_contains "$(cat "$SYNC")" 'kcode-rebuild-g7' \
    'sync still special-cases a historical task id'

  assert_present "$destination/projects/product/README.md" 'sync deleted an existing local product checkout'
  assert_present "$destination/projects/legacy/local.txt" 'sync deleted an existing ignored local product directory'
  assert_absent "$destination/.gitmodules" 'sync preserved stale .gitmodules metadata'
  [ -z "$(git -C "$destination" ls-files -- projects)" ] \
    || fail 'sync left tracked projects entries in the destination index'
  gitlinks=$(git -C "$destination" ls-files -s | awk '$1 == "160000" {print $4}')
  [ -z "$gitlinks" ] || fail "sync left tracked gitlinks: $gitlinks"
  assert_grep 'projects/' "$destination/.gitignore" 'sync ignore contract does not exclude projects/'
  while IFS=$'\t' read -r kind value; do
    case "$kind" in
      directory) expected="data/**/$value/" ;;
      extension) expected="data/**/*.$value" ;;
      \#*|'') continue ;;
    esac
    assert_grep "$expected" "$destination/.gitignore" \
      "generated ignore contract omitted $kind $value"
  done < "$ROOT/config/kcode-data-policy.tsv"

  assert_grep 'verify' "$log" 'sync did not verify the captured skill snapshot'
  assert_grep "verify-live --from-home $live --user-home $temp/user" "$log" \
    'sync did not compare every live skill root with the capture'
  assert_grep 'integrity' "$log" 'sync did not run the complete fork integrity gate before commit'
  assert_no_grep 'submodule update' "$SYNC" 'obsolete project update behavior remains in sync'
  pass 'sync removes stale product tracking while preserving local ignored checkouts and fork surfaces'
}

test_sync_removes_large_project_index() {
  local temp live destination product log blob tracked
  temp=$(fm_test_tmproot kcode-sync-large-index)
  live="$temp/live"
  destination="$temp/k-code"
  product="$temp/product"
  log="$temp/skill-manager.log"
  build_fixture "$temp" "$live" "$destination" "$product"

  blob=$(printf 'stale product entry\n' | git -C "$destination" hash-object -w --stdin)
  for n in $(seq 1 12000); do
    printf '100644 %s\tprojects/bulk/file-%05d\n' "$blob" "$n"
  done | git -C "$destination" update-index --index-info

  FM_HOME="$live" KCODE_DIR="$destination" KCODE_SKILL_USER_HOME="$temp/user" \
    KCODE_SKILL_LOG="$log" KCODE_SYNC_DRY_RUN=1 "$SYNC" >/dev/null

  tracked=$(git -C "$destination" ls-files -- projects)
  [ -z "$tracked" ] || fail 'sync left entries from a large projects index'
  pass 'sync deterministically removes a large tracked projects index'
}

test_sync_rejects_non_project_gitlink() {
  local temp live destination product log out rc
  temp=$(fm_test_tmproot kcode-sync-gitlink)
  live="$temp/live"
  destination="$temp/k-code"
  product="$temp/product"
  log="$temp/skill-manager.log"
  build_fixture "$temp" "$live" "$destination" "$product"

  # First normalize and commit the fixture, then introduce a gitlink in a
  # protected non-project path to prove the final invariant covers the full index.
  FM_HOME="$live" KCODE_DIR="$destination" KCODE_SKILL_USER_HOME="$temp/user" \
    KCODE_SKILL_LOG="$log" KCODE_SYNC_DRY_RUN=1 "$SYNC" >/dev/null
  git -C "$destination" commit -qm 'normalized fixture'
  git -c protocol.file.allow=always -C "$destination" submodule add -q \
    "$product" assets/kcode/dependency
  git -C "$destination" commit -qam 'add forbidden non-project gitlink'

  rc=0
  out=$(FM_HOME="$live" \
    KCODE_DIR="$destination" \
    KCODE_SKILL_USER_HOME="$temp/user" \
    KCODE_SKILL_LOG="$log" \
    KCODE_SYNC_DRY_RUN=1 \
    "$SYNC" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail 'sync accepted a non-project gitlink'
  assert_contains "$out" 'refusing to continue with tracked gitlinks' \
    'gitlink refusal did not explain the invariant'
  pass 'sync rejects every gitlink, not only paths under projects/'
}

test_sync_preserves_local_products_but_removes_tracking
test_sync_removes_large_project_index
test_sync_rejects_non_project_gitlink
