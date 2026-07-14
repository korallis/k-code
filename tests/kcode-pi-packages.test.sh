#!/usr/bin/env bash
# Regression coverage for project-local Pi package parity in a trusted clean clone.
set -euo pipefail

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SETTINGS="$ROOT/.pi/settings.json"
EXPECTED_PACKAGES='npm:pi-xai-oauth@1.3.3
npm:pi-claude-bridge@0.6.2'
EXPECTED_PI_PATHS='.pi/extensions/fm-primary-pi-watch.ts
.pi/extensions/fm-primary-turnend-guard.ts
.pi/settings.json'

settings_packages() {
  python3 - "$1" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)
packages = data.get("packages")
if not isinstance(packages, list) or not all(isinstance(item, str) for item in packages):
    raise SystemExit("packages must be an array of strings")
print("\n".join(packages))
PY
}

test_exact_project_package_declarations() {
  local actual identities
  assert_present "$SETTINGS" 'project-local Pi settings are missing'
  actual=$(settings_packages "$SETTINGS")
  [ "$actual" = "$EXPECTED_PACKAGES" ] \
    || fail "project-local Pi packages are not the exact reviewed pins: $actual"
  identities=$(printf '%s\n' "$actual" | sed -E 's/^npm://; s/@[0-9][^@]*$//' | LC_ALL=C sort)
  [ "$(printf '%s\n' "$identities" | uniq -d)" = '' ] \
    || fail 'a Pi package identity is declared more than once'
  pass 'project settings pin each reviewed Pi provider package exactly once'
}

test_pi_surface_has_no_duplicate_extensions_or_runtime_data() {
  local actual
  actual=$(git -C "$ROOT" ls-files -- .pi | LC_ALL=C sort)
  [ "$actual" = "$EXPECTED_PI_PATHS" ] \
    || fail "tracked .pi surface must contain only two Firstmate extensions and package settings: $actual"
  git -C "$ROOT" check-ignore -q .pi/npm/package-lock.json \
    || fail 'project-local Pi npm store is not ignored'
  git -C "$ROOT" check-ignore -q .pi/git/example/package.json \
    || fail 'project-local Pi git package store is not ignored'
  git -C "$ROOT" check-ignore -q .pi/claude-bridge.json \
    || fail 'Claude bridge user configuration is not ignored'
  git -C "$ROOT" check-ignore -q .pi/cc-cli-logs/example.log \
    || fail 'Claude bridge logs are not ignored'
  git -C "$ROOT" check-ignore -q .pi/sessions/example.json \
    || fail 'Pi sessions are not ignored'
  pass 'tracked Pi surface excludes duplicate provider source and private runtime data'
}

test_clean_clone_carries_declarations_only() {
  local temp clone actual
  temp=$(mktemp -d "${TMPDIR:-/tmp}/kcode-pi-clean.XXXXXX")
  clone="$temp/clone"
  mkdir -p "$clone"
  git -C "$ROOT" archive "$(git -C "$ROOT" write-tree)" | tar -x -C "$clone"

  actual=$(settings_packages "$clone/.pi/settings.json")
  [ "$actual" = "$EXPECTED_PACKAGES" ] \
    || fail 'clean archive does not carry both exact project-local package pins'
  actual=$(find "$clone/.pi" -type f -print \
    | while IFS= read -r path; do printf '%s\n' "${path#"$clone/"}"; done \
    | LC_ALL=C sort)
  [ "$actual" = "$EXPECTED_PI_PATHS" ] \
    || fail "clean archive includes unexpected Pi package source or runtime data: $actual"
  pass 'clean clone carries declarations and two Firstmate extensions without package copies'
}

test_all_fleet_routes_stay_inside_pi() {
  python3 - "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
if (root / "config/crew-harness").read_text(encoding="utf-8") != "pi\n":
    raise SystemExit("crew harness is not pinned to Pi")
if (root / "config/secondmate-harness").read_text(encoding="utf-8") != (
    "pi claude-bridge/claude-fable-5 max\n"
):
    raise SystemExit("secondmate is not routed to Fable 5 through Pi")
with (root / "config/crew-dispatch.json").open(encoding="utf-8") as handle:
    dispatch = json.load(handle)
profiles = []
for rule in dispatch["rules"]:
    use = rule["use"]
    rule_profiles = use if isinstance(use, list) else [use]
    profiles.extend(rule_profiles)
    profiles.extend(
        profile["quota"]["fallback"]
        for profile in rule_profiles
        if isinstance(profile.get("quota"), dict)
        and isinstance(profile["quota"].get("fallback"), dict)
    )
profiles.append(dispatch["default"])
if any(profile["harness"] != "pi" for profile in profiles):
    raise SystemExit("a dispatch profile escapes Pi")
research = next(rule for rule in dispatch["rules"] if "research OR planning" in rule["when"])
if research.get("select") != "all" or len(research["use"]) != 3:
    raise SystemExit("research triad does not fan out all three profiles")
if research["use"][2] != {
    "harness": "pi",
    "model": "claude-bridge/claude-fable-5",
    "effort": "max",
    "quota": {
        "provider": "claude",
        "window": "model:fable",
        "percentRemainingAbove": 0,
        "fallback": {
            "harness": "pi",
            "model": "claude-bridge/claude-opus-4-8",
            "effort": "max",
        },
    },
}:
    raise SystemExit("research triad third profile lacks its executable Pi quota fallback")
PY
  pass 'crew, secondmate, and research triad provider routes all stay inside Pi'
}

test_readme_explains_install_and_auth_boundaries() {
  assert_contains "$(cat "$ROOT/README.md")" 'npm:pi-xai-oauth@1.3.3' \
    'README omits the pinned xAI provider package'
  assert_contains "$(cat "$ROOT/README.md")" 'npm:pi-claude-bridge@0.6.2' \
    'README omits the pinned Claude bridge package'
  assert_contains "$(cat "$ROOT/README.md")" 'pi /login xai-auth' \
    'README omits the explicit xAI login step'
  assert_contains "$(cat "$ROOT/README.md")" 'separately authenticated Claude Code' \
    'README omits the Claude Code authentication boundary'
  assert_contains "$(cat "$ROOT/README.md")" 'fm-primary-pi-watch.ts' \
    'README does not distinguish the Firstmate Pi extensions'
  assert_contains "$(cat "$ROOT/README.md")" 'fm-primary-turnend-guard.ts' \
    'README does not distinguish the Firstmate Pi extensions'
  assert_contains "$(cat "$ROOT/README.md")" 'Firstmate owns lifecycle operations' \
    'README implies operators routinely drive internal Firstmate commands'
  pass 'README documents Pi package installation, extension ownership, and authentication'
}

test_exact_project_package_declarations
test_pi_surface_has_no_duplicate_extensions_or_runtime_data
test_clean_clone_carries_declarations_only
test_all_fleet_routes_stay_inside_pi
test_readme_explains_install_and_auth_boundaries
