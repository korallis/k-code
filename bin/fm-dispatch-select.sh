#!/usr/bin/env bash
# Resolve one already-matched crew-dispatch rule to a concrete profile.
# Usage:
#   fm-dispatch-select.sh [--select <strategy>] [--quota-json <file>] [<rule-or-use-json>]
#
# Input may be a full rule object with `use` and optional `select`, a single
# profile object, or an ordered array of profile objects.
# Output is one compact JSON profile object on stdout, except `select: all`,
# which outputs an ordered compact JSON array after resolving quota guards.
#
# `all` profile quota guards are deterministic:
#   - A guarded profile is used only when its named provider is fresh and its
#     named window has percentRemaining strictly above percentRemainingAbove.
#   - Exhausted, missing, stale, unparseable, or unavailable quota selects the
#     guard's declared fallback profile; unguarded sibling profiles are unchanged.
#   - Quota is read once for the complete fan-out.
#
# quota-balanced is deterministic, and this header is the single owner of its
# contract:
#   - It runs quota-axi --json (or the --quota-json fixture).
#   - Per candidate vendor it takes the minimum percentRemaining across that
#     vendor's GENERAL windows only - Claude five_hour and seven_day, Codex
#     five_hour and weekly - ignoring model-scoped windows such as model:fable
#     and model:codex_bengalfox:*.
#   - The vendor with the higher minimum remaining quota wins; an exact tie
#     between equally trusted candidates uses the first array element.
#   - Stale-but-cached general-window numbers are usable, but a fresh candidate
#     wins unless the stale candidate's minimum is at least the stale-clear
#     margin higher (default 20 points - the definition of "clearly less
#     constrained").
#   - A vendor absent from quota output, or with no usable general windows, is
#     unavailable; selection happens among available candidates.
#   - If quota-axi is missing, exits non-zero, returns unparseable JSON, or no
#     candidate is usable, the reason is logged to stderr and the first array
#     element is printed - quota trouble never blocks dispatch.
#
# quota-balanced uses quota-axi --json unless --quota-json supplies a fixture.
# FM_DISPATCH_QUOTA_AXI overrides the quota command.
# FM_DISPATCH_STALE_CLEAR_MARGIN overrides the default 20 point stale margin.
set -u

STALE_CLEAR_MARGIN=${FM_DISPATCH_STALE_CLEAR_MARGIN:-20}
SELECT_OVERRIDE=
QUOTA_JSON_FILE=
ARGS=()

usage() {
  awk '
    NR == 1 { next }
    /^#/ { sub(/^# ?/, ""); print; next }
    { exit }
  ' "$0" >&2
}

log() {
  printf 'fm-dispatch-select: %s\n' "$*" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --select)
      [ "$#" -gt 1 ] || { echo "error: --select requires a value" >&2; exit 2; }
      SELECT_OVERRIDE=$2
      shift 2
      ;;
    --select=*)
      SELECT_OVERRIDE=${1#--select=}
      shift
      ;;
    --quota-json)
      [ "$#" -gt 1 ] || { echo "error: --quota-json requires a file" >&2; exit 2; }
      QUOTA_JSON_FILE=$2
      shift 2
      ;;
    --quota-json=*)
      QUOTA_JSON_FILE=${1#--quota-json=}
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        ARGS+=("$1")
        shift
      done
      ;;
    -*)
      echo "error: unknown option $1" >&2
      exit 2
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

[ "${#ARGS[@]}" -le 1 ] || { echo "error: expected at most one JSON argument" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "error: jq is required" >&2; exit 2; }

if [ "${#ARGS[@]}" -eq 1 ]; then
  SPEC_JSON=${ARGS[0]}
else
  SPEC_JSON=$(cat)
fi

profiles_json=$(printf '%s\n' "$SPEC_JSON" | jq -ec '
  (if type == "object" and has("use") then .use else . end)
  | if type == "array" then .
    elif type == "object" then [.]
    else empty
    end
' 2>/dev/null) || { echo "error: dispatch input must be a rule, profile, or profile array" >&2; exit 2; }

profile_count=$(printf '%s\n' "$profiles_json" | jq 'length')
[ "$profile_count" -gt 0 ] || { echo "error: dispatch profile array must not be empty" >&2; exit 2; }

first_profile() {
  printf '%s\n' "$profiles_json" | jq -c '
    def clean($p):
      {harness: $p.harness}
      + (if ($p.model? | type) == "string" then {model: $p.model} else {} end)
      + (if ($p.effort? | type) == "string" then {effort: $p.effort} else {} end);
    clean(.[0])
  '
}

clean_profiles() {
  printf '%s\n' "$profiles_json" | jq -c '
    def clean($p):
      {harness: $p.harness}
      + (if ($p.model? | type) == "string" then {model: $p.model} else {} end)
      + (if ($p.effort? | type) == "string" then {effort: $p.effort} else {} end);
    map(clean(.))
  '
}

load_quota() {
  if [ -n "$QUOTA_JSON_FILE" ]; then
    if ! quota_json=$(cat "$QUOTA_JSON_FILE" 2>/dev/null); then
      log "cannot read quota JSON"
      return 1
    fi
  else
    quota_cmd=${FM_DISPATCH_QUOTA_AXI:-quota-axi}
    if ! command -v "$quota_cmd" >/dev/null 2>&1; then
      log "quota-axi missing"
      return 1
    fi
    quota_json=$("$quota_cmd" --json 2>/dev/null)
    quota_status=$?
    if [ "$quota_status" -ne 0 ]; then
      log "quota-axi exited $quota_status"
      return 1
    fi
  fi

  if ! printf '%s\n' "$quota_json" | jq -e 'type == "object" and (.providers | type) == "array"' >/dev/null 2>&1; then
    log "quota-axi returned unparseable JSON"
    return 1
  fi
  return 0
}

select_strategy=$SELECT_OVERRIDE
if [ -z "$select_strategy" ]; then
  select_strategy=$(printf '%s\n' "$SPEC_JSON" | jq -r '
    if type == "object" and has("use") and (.select? | type) == "string" then .select else "" end
  ' 2>/dev/null || true)
fi

if [ "$select_strategy" = all ]; then
  if ! printf '%s\n' "$profiles_json" | jq -e '
    all(.[];
      (.quota? == null) or
      ((.quota | type) == "object"
        and (.quota.provider | type) == "string"
        and (.quota.window | type) == "string"
        and (.quota.percentRemainingAbove | type) == "number"
        and (.quota.fallback | type) == "object"
        and (.quota.fallback.harness | type) == "string"
        and (.quota.fallback.quota? == null)))
  ' >/dev/null 2>&1; then
    echo "error: malformed select all quota guard" >&2
    exit 2
  fi
  if ! printf '%s\n' "$profiles_json" | jq -e 'any(.[]; .quota? != null)' >/dev/null; then
    clean_profiles
    exit 0
  fi
  if ! load_quota; then
    log "using declared fallbacks for guarded profiles"
    printf '%s\n' "$profiles_json" | jq -c '
      def clean($p):
        {harness: $p.harness}
        + (if ($p.model? | type) == "string" then {model: $p.model} else {} end)
        + (if ($p.effort? | type) == "string" then {effort: $p.effort} else {} end);
      map(if .quota? != null then clean(.quota.fallback) else clean(.) end)
    '
    exit 0
  fi
  printf '%s\n' "$quota_json" | jq -c --argjson profiles "$profiles_json" '
    def clean($p):
      {harness: $p.harness}
      + (if ($p.model? | type) == "string" then {model: $p.model} else {} end)
      + (if ($p.effort? | type) == "string" then {effort: $p.effort} else {} end);
    def resolve($p):
      if $p.quota? == null then clean($p)
      else
        ($p.quota) as $guard
        | ([.providers[]? | select(.provider == $guard.provider)][0]) as $provider
        | ([($provider.windows // [])[]? | select(.id == $guard.window)][0]) as $window
        | if $provider != null
            and (($provider.state.status? // "") == "fresh")
            and $window != null
            and (($window.percentRemaining? | type) == "number")
            and ($window.percentRemaining > $guard.percentRemainingAbove)
          then clean($p)
          else clean($guard.fallback)
          end
      end;
    . as $quota | [$profiles[] as $profile | $quota | resolve($profile)]
  '
  exit 0
fi

if [ "$select_strategy" != quota-balanced ]; then
  if [ -n "$select_strategy" ]; then
    log "unknown select strategy '$select_strategy'; using first profile"
  fi
  first_profile
  exit 0
fi

if ! load_quota; then
  log "using first profile"
  first_profile
  exit 0
fi

selection=$(printf '%s\n' "$quota_json" | jq -ec \
  --argjson profiles "$profiles_json" \
  --argjson margin "$STALE_CLEAR_MARGIN" '
  def clean($p):
    {harness: $p.harness}
    + (if ($p.model? | type) == "string" then {model: $p.model} else {} end)
    + (if ($p.effort? | type) == "string" then {effort: $p.effort} else {} end);
  def provider_for($h): [.providers[]? | select(.provider == $h)][0];
  def general_ids($h):
    if $h == "claude" then ["five_hour", "seven_day"]
    elif $h == "codex" then ["five_hour", "weekly"]
    else []
    end;
  def candidate_metric($p; $i):
    . as $root
    | ($p.harness // "") as $h
    | ($root | provider_for($h)) as $provider
    | if ($provider == null) or ((general_ids($h) | length) == 0) then empty
      else
        (($provider.windows // [])
          | map(. as $window
            | select(((general_ids($h) | index($window.id)) != null)
              and (($window.kind? // "") != "model")
              and (($window.percentRemaining? | type) == "number")))) as $windows
        | if ($windows | length) == 0 then empty
          else {
            index: $i,
            profile: clean($p),
            harness: $h,
            min: ($windows | map(.percentRemaining) | min),
            fresh: (($provider.state.status? // "") == "fresh")
          }
          end
      end;
  def better($a; $b):
    if $a == null then $b
    elif $b == null then $a
    elif ($b.min > $a.min) then $b
    elif ($b.min == $a.min and $b.index < $a.index) then $b
    else $a
    end;
  def best_by_min($xs): reduce $xs[] as $x (null; better(.; $x));
  . as $quota_root
  | ([$profiles | to_entries[] | . as $entry | ($quota_root | candidate_metric($entry.value; $entry.key))]) as $candidates
  | if ($candidates | length) == 0 then {
      fallback: true,
      reason: "no usable quota windows for candidate vendors",
      profile: clean($profiles[0])
    }
    else
      (best_by_min($candidates | map(select(.fresh)))) as $fresh_best
      | (best_by_min($candidates | map(select(.fresh | not)))) as $stale_best
      | (if $fresh_best != null and $stale_best != null then
          if $stale_best.min >= ($fresh_best.min + $margin) then $stale_best else $fresh_best end
        elif $fresh_best != null then $fresh_best
        else $stale_best
        end) as $chosen
      | {fallback: false, profile: $chosen.profile}
    end
' 2>/dev/null) || {
  log "quota-axi data could not be evaluated; using first profile"
  first_profile
  exit 0
}

if [ "$(printf '%s\n' "$selection" | jq -r '.fallback')" = true ]; then
  log "$(printf '%s\n' "$selection" | jq -r '.reason'); using first profile"
fi
printf '%s\n' "$selection" | jq -c '.profile'
