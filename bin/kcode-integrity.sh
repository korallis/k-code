#!/usr/bin/env bash
# kcode-integrity.sh - the single owner of k-code packaging integrity checks.
#
# This is intentionally narrower than upstream Firstmate development CI.
# It verifies the public operating-home boundary, captured skills, relative
# documentation links, JSON routing config, and common secret or PHI shapes.
#
# Usage: bin/kcode-integrity.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail=0

required=(
  README.md
  AGENTS.md
  LICENSE
  .tasks.toml
  .gitattributes
  .no-mistakes.yaml
  config/crew-dispatch.json
  bin/kcode-sync.sh
  bin/kcode-skills.sh
  bin/kcode-integrity.sh
  tests/kcode-sync.test.sh
  tests/kcode-skills.test.sh
  skill-snapshot/README.md
  skill-snapshot/roots.tsv
  skill-snapshot/sources.tsv
  skill-snapshot/harness-managed.tsv
  skill-snapshot/restore.tsv
  skill-snapshot/checksums.sha256
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

if git ls-files | grep -E '^(state/|projects/|\.no-mistakes/|\.lavish/)'; then
  printf 'kcode-integrity: volatile runtime or product path is tracked\n' >&2
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

secret_patterns=(
  'ghp_[A-Za-z0-9]{36,}'
  'gho_[A-Za-z0-9]{36,}'
  'github_pat_[A-Za-z0-9_]{20,}'
  'sk-[A-Za-z0-9]{32,}'
  'xox[baprs]-[A-Za-z0-9-]{20,}'
  'AKIA[0-9A-Z]{16}'
  'BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY'
)
phi_patterns=(
  '(^|[^0-9])[0-9]{3}-[0-9]{2}-[0-9]{4}([^0-9]|$)'
  '(MRN|medical record number)[[:space:]_:#=-]*[A-Z0-9]{6,}'
  '(patient|member)[[:space:]_-]*(name|id)[[:space:]_:#=-]+[A-Za-z0-9][A-Za-z0-9._-]{4,}'
  '(DOB|date of birth)[[:space:]_:#=-]+(19|20)[0-9]{2}[-/][0-9]{1,2}[-/][0-9]{1,2}'
)
for pattern in "${secret_patterns[@]}"; do
  if grep -RInE --exclude-dir=.git --exclude-dir=projects --exclude-dir=node_modules \
      --exclude='*.jpg' --exclude='*.png' --exclude='*.gif' --exclude='*.mp4' \
      --exclude='*.bundle' -e "$pattern" .; then
    printf 'kcode-integrity: secret pattern matched: %s\n' "$pattern" >&2
    fail=1
  fi
done
for pattern in "${phi_patterns[@]}"; do
  if grep -RInEi --exclude-dir=.git --exclude-dir=projects --exclude-dir=node_modules \
      --exclude='*.jpg' --exclude='*.png' --exclude='*.gif' --exclude='*.mp4' \
      --exclude='*.bundle' -e "$pattern" .; then
    printf 'kcode-integrity: possible PHI pattern matched: %s\n' "$pattern" >&2
    fail=1
  fi
done
if grep -RInE --exclude-dir=.git --exclude-dir=projects \
    'FMX_PAIRING_TOKEN=[A-Za-z0-9_-]{20,}' .; then
  printf 'kcode-integrity: possible real FMX_PAIRING_TOKEN is present\n' >&2
  fail=1
fi

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

python3 -c "import json; json.load(open('config/crew-dispatch.json'))"
bin/kcode-skills.sh verify

[ "$fail" -eq 0 ] || exit "$fail"
printf 'kcode-integrity: repository boundaries, docs, skills, secrets, and PHI checks passed.\n'
