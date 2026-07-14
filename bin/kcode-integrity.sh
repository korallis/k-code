#!/usr/bin/env bash
# kcode-integrity.sh - the single owner of k-code packaging integrity checks.
#
# This is intentionally narrower than upstream Firstmate development CI.
# It verifies the public operating-home boundary, captured skills, relative
# documentation links, JSON routing config, and common secret or PHI shapes.
#
# Usage: bin/kcode-integrity.sh [--content-scan-only]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail=0

scan_tracked_text_pattern() {
  local label=$1 ignore_case=$2 pattern=$3 entry metadata mode object stage path matched=0
  while IFS= read -r -d '' entry; do
    metadata=${entry%%$'\t'*}
    mode=${metadata%% *}
    object=${metadata#* }
    object=${object%% *}
    stage=${metadata##* }
    path=${entry#*$'\t'}
    case "$mode:$stage" in
      100644:0|100755:0) ;;
      *) continue ;;
    esac
    if [ "$ignore_case" -eq 1 ]; then
      git cat-file blob "$object" | LC_ALL=C grep -IEi -e "$pattern" >/dev/null || continue
    else
      git cat-file blob "$object" | LC_ALL=C grep -IE -e "$pattern" >/dev/null || continue
    fi
    printf 'kcode-integrity: %s %s matched tracked text path %q\n' \
      "$label" "$pattern" "$path" >&2
    matched=1
  done < <(git ls-files --stage -z)
  [ "$matched" -eq 0 ] || fail=1
}

scan_tracked_data_policy() {
  local path matched=0
  while IFS= read -r -d '' path; do
    if printf '%s\n' "$path" | LC_ALL=C grep -Eiq \
      '^data/(.*/)?((screenshots?|gifs?|previews?|renders?)(/|$)|[^/]+\.(bundle|gif|png|jpe?g|webp)$)'; then
      printf 'kcode-integrity: generated data artifact is tracked: %q\n' "$path" >&2
      matched=1
    fi
  done < <(git ls-files -z -- data)
  [ "$matched" -eq 0 ] || fail=1
}

scan_tracked_content() {
  local pattern
  local secret_patterns=(
    'ghp_[A-Za-z0-9]{36,}'
    'gho_[A-Za-z0-9]{36,}'
    'github_pat_[A-Za-z0-9_]{20,}'
    'sk-[A-Za-z0-9]{32,}'
    'xox[baprs]-[A-Za-z0-9-]{20,}'
    'AKIA[0-9A-Z]{16}'
    'BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY'
  )
  local phi_patterns=(
    '(^|[^0-9])[0-9]{3}-[0-9]{2}-[0-9]{4}([^0-9]|$)'
    '(MRN|medical record number)[[:space:]_:#=-]*[A-Z0-9]{6,}'
    '(patient|member)[[:space:]_-]*(name|id)[[:space:]_:#=-]+[A-Za-z0-9][A-Za-z0-9._-]{4,}'
    '(DOB|date of birth)[[:space:]_:#=-]+(19|20)[0-9]{2}[-/][0-9]{1,2}[-/][0-9]{1,2}'
  )

  for pattern in "${secret_patterns[@]}"; do
    scan_tracked_text_pattern 'secret pattern' 0 "$pattern"
  done
  for pattern in "${phi_patterns[@]}"; do
    scan_tracked_text_pattern 'possible PHI pattern' 1 "$pattern"
  done
  scan_tracked_text_pattern 'possible FMX pairing token pattern' 0 \
    'FMX_PAIRING_TOKEN=[A-Za-z0-9_-]{20,}'
  scan_tracked_data_policy
}

if [ "${1:-}" = '--content-scan-only' ]; then
  [ "$#" -eq 1 ] || { printf 'usage: %s [--content-scan-only]\n' "$0" >&2; exit 2; }
  scan_tracked_content
  exit "$fail"
elif [ "$#" -ne 0 ]; then
  printf 'usage: %s [--content-scan-only]\n' "$0" >&2
  exit 2
fi

required=(
  README.md
  AGENTS.md
  LICENSE
  .tasks.toml
  .gitattributes
  .no-mistakes.yaml
  .pi/settings.json
  config/crew-dispatch.json
  config/crew-harness
  config/secondmate-harness
  bin/kcode-sync.sh
  bin/kcode-skills.sh
  bin/kcode-integrity.sh
  tests/kcode-sync.test.sh
  tests/kcode-skills.test.sh
  tests/kcode-pi-packages.test.sh
  tests/kcode-integrity.test.sh
  tests/kcode-validation-isolation.test.sh
  skill-snapshot/README.md
  skill-snapshot/roots.tsv
  skill-snapshot/sources.tsv
  skill-snapshot/harness-managed.tsv
  skill-snapshot/overlays.tsv
  skill-snapshot/restore.tsv
  skill-snapshot/checksums.sha256
  skill-snapshot/modes.tsv
)
for path in "${required[@]}"; do
  [ -e "$path" ] || { printf 'kcode-integrity: missing %s\n' "$path" >&2; exit 1; }
done
for asset in \
  assets/kcode/hero-banner.jpg \
  assets/kcode/fleet-architecture.jpg \
  assets/kcode/security-boundary.jpg \
  assets/kcode/PROVENANCE.md \
  docs/assets/hero-banner.jpg; do
  [ -f "$asset" ] || { printf 'kcode-integrity: missing %s\n' "$asset" >&2; exit 1; }
done

if git ls-files | grep -E '^(state/|projects/|\.no-mistakes/|\.lavish/|\.pi/(npm|git|cc-cli-logs|sessions)/)'; then
  printf 'kcode-integrity: volatile runtime, package-store, or product path is tracked\n' >&2
  fail=1
fi
if git ls-files -- .pi | grep -E '(^|/)(auth\.json|claude-bridge\.json|claude-bridge\.log)$|\.pi/extensions/(xai-oauth|claude-bridge|index)\.ts$'; then
  printf 'kcode-integrity: Pi credentials, bridge state, or duplicate provider source is tracked\n' >&2
  fail=1
fi
if git ls-files | grep -E '(^|/)(pi-xai-oauth|pi-claude-bridge)/'; then
  printf 'kcode-integrity: Pi provider package source must be installed from its pinned declaration, not vendored\n' >&2
  fail=1
fi
if git ls-files --error-unmatch .gitmodules >/dev/null 2>&1; then
  printf 'kcode-integrity: .gitmodules must not be tracked\n' >&2
  fail=1
fi
gitlinks=$(git ls-files -s | awk '$1 == "160000" {print $4}')
if [ -n "$gitlinks" ]; then
  printf 'kcode-integrity: gitlinks must not be tracked:\n%s\n' "$gitlinks" >&2
  fail=1
fi
if git ls-files | grep -E '(^|/)\.env$|\.key$|(^|/)(credentials?|tokens?)(\.[^/]*)?$|cmux-socket-password|^config/x-mode\.env$'; then
  printf 'kcode-integrity: forbidden secret or runtime path is tracked\n' >&2
  fail=1
fi

scan_tracked_content

if grep -Ei 'recurse-submodules|projects/(k-zero|service-referral)|private submodule|project submodules|submodule pointers' README.md; then
  printf 'kcode-integrity: README contains obsolete product-bundling guidance\n' >&2
  fail=1
fi

python3 - <<'PY'
import re
import sys
from pathlib import Path

root = Path(".").resolve()
markdown_files = [
    Path("README.md"),
    Path("assets/kcode/PROVENANCE.md"),
    Path("skill-snapshot/README.md"),
]
link_re = re.compile(r"\[([^\]]*)\]\(([^)]+)\)")
html_image_re = re.compile(r'<img[^>]+src="([^"]+)"')
missing = []
checked = 0
for markdown in markdown_files:
    text = markdown.read_text(encoding="utf-8", errors="replace")
    targets = [match.group(2).strip() for match in link_re.finditer(text)]
    targets.extend(match.group(1).strip() for match in html_image_re.finditer(text))
    for target in targets:
        if target.startswith(("http://", "https://", "mailto:", "#")):
            continue
        path_part = target.split()[0].split("#")[0]
        if not path_part:
            continue
        resolved = (markdown.parent / path_part).resolve()
        checked += 1
        try:
            resolved.relative_to(root)
        except ValueError:
            missing.append(f"{markdown}: escapes root -> {target}")
            continue
        if not resolved.exists():
            missing.append(f"{markdown}: missing {target}")
print(f"kcode-integrity: checked {checked} relative links across {len(markdown_files)} files")
if missing:
    print("\n".join(missing), file=sys.stderr)
    sys.exit(1)
PY

python3 - <<'PY'
import json
from pathlib import Path

with Path("config/crew-dispatch.json").open(encoding="utf-8") as handle:
    dispatch = json.load(handle)
with Path(".pi/settings.json").open(encoding="utf-8") as handle:
    package_settings = json.load(handle)

if Path("config/crew-harness").read_text(encoding="utf-8") != "pi\n":
    raise SystemExit("kcode-integrity: config/crew-harness must pin Pi")
if Path("config/secondmate-harness").read_text(encoding="utf-8") != (
    "pi claude-bridge/claude-fable-5 max\n"
):
    raise SystemExit("kcode-integrity: secondmates must use Fable 5 through Pi")

profiles = []
for rule in dispatch.get("rules", []):
    use = rule.get("use", [])
    profiles.extend(use if isinstance(use, list) else [use])
profiles.append(dispatch.get("default", {}))
if not profiles or any(profile.get("harness") != "pi" for profile in profiles):
    raise SystemExit("kcode-integrity: every dispatch profile must stay on Pi")
research_rules = [
    rule for rule in dispatch.get("rules", [])
    if "research OR planning" in rule.get("when", "")
]
expected_third = {
    "harness": "pi",
    "model": "claude-bridge/claude-fable-5",
    "effort": "max",
}
research_use = research_rules[0].get("use", []) if len(research_rules) == 1 else []
if (
    not isinstance(research_use, list)
    or len(research_use) != 3
    or research_rules[0].get("select") != "all"
    or research_use[2] != expected_third
):
    raise SystemExit("kcode-integrity: research triad must fan out all three Pi profiles")
why = research_rules[0].get("why", "")
if "claude-bridge/claude-opus-4-8" not in why or "never the standalone Claude harness" not in why:
    raise SystemExit("kcode-integrity: research triad must document the Pi bridge Opus fallback")

required = ["npm:pi-xai-oauth@1.3.3", "npm:pi-claude-bridge@0.6.2"]
packages = package_settings.get("packages")
if packages != required:
    raise SystemExit(
        "kcode-integrity: .pi/settings.json must declare each reviewed provider package exactly once"
    )

expected_pi_paths = [
    ".pi/extensions/fm-primary-pi-watch.ts",
    ".pi/extensions/fm-primary-turnend-guard.ts",
    ".pi/settings.json",
]
import subprocess

actual_pi_paths = subprocess.check_output(
    ["git", "ls-files", "--", ".pi"], text=True
).splitlines()
if sorted(actual_pi_paths) != expected_pi_paths:
    raise SystemExit(
        "kcode-integrity: tracked .pi surface must be the two Firstmate extensions plus settings"
    )
PY
bin/kcode-skills.sh verify

[ "$fail" -eq 0 ] || exit "$fail"
printf 'kcode-integrity: repository boundaries, docs, skills, secrets, and PHI checks passed.\n'
