# Scout report: Firstmate `fm-validation` live terminal dashboard (gist draft)

**Task:** `tui-gist-v3` (scout)  
**Date:** 2026-07-13  
**Scope:** Document how to reproduce Firstmate’s validation TUI independently; produce a publish-ready Gist draft. Do **not** publish.

## Publication outcome

Firstmate reviewed, privacy-scanned, ShellCheck-validated, smoke-tested, and published the five-file draft as an unlisted Gist:
https://gist.github.com/korallis/e43956fd375efa96ea2c56529e49d4fd

The published files are `README.md`, `live-status-dashboard.sh`, `fake-state.sh`, `test-dashboard.sh`, and `LICENSE`.
The README extraction was corrected before delivery and browser-verified through its final Troubleshooting, Validation checks, Source references, and License sections.

---

## What I did

1. Confirmed this worktree (`origin/main` at `b708731`) does **not** contain `bin/fm-validation-dashboard.sh` or `bin/fm-dashboard-launch.sh`.
2. Located the authoritative implementation on the primary firstmate home (local untracked files):
   - `bin/fm-validation-dashboard.sh` (110 lines)
   - `bin/fm-dashboard-launch.sh` (51 lines)
   - `tests/fm-validation-dashboard.test.sh` (61 lines)
3. Read related accurate-state machinery: `bin/fm-crew-state.sh` (header + reconciliation contract; ~576 lines total).
4. Ran the hermetic unit test: **PASS (a)(b)(c)**.
5. Ran a two-task single-frame demo with a throwaway `FM_HOME` and a fake `fm-crew-state.sh`; verified table layout and note surfacing.
6. Drafted a standalone multi-file Gist below (title, description, Markdown guide, optional shell + test files) with a privacy audit.

---

## What I found (evidence)

### Source location / landing status

| Artifact | Location | Git status (primary home) |
| --- | --- | --- |
| Dashboard loop | `bin/fm-validation-dashboard.sh` | untracked (`??`) |
| Herdr launcher | `bin/fm-dashboard-launch.sh` | untracked (`??`) |
| Behavior test | `tests/fm-validation-dashboard.test.sh` | untracked (`??`) |
| Accurate state helper | `bin/fm-crew-state.sh` | tracked (shared firstmate) |

These dashboard scripts are **not** on `origin/main` of the public firstmate tree at the scout worktree HEAD. Treat the gist as “how Firstmate’s live home implements this,” not as “already published upstream.”

### Observable behavior (production scripts)

**Entry / lifecycle**

- Usage: `bin/fm-validation-dashboard.sh [<interval-seconds>]` (default `4`).
- `FM_HOME` selects the fleet home; otherwise parent of `bin/`.
- `FM_DASH_ONCE=1` prints one composed frame and exits (tests / non-interactive).
- Interactive path: one initial full clear (`\033[2J`), hide cursor (`tput civis` / `\033[?25l`), loop `render` + `sleep`, restore cursor on INT/TERM.

**Task discovery**

- Globs `$FM_HOME/state/*.meta` (`nullglob`).
- Per meta: task id = basename without `.meta`; project = basename of `project=` field; crew = `harness=` field.
- Empty set → padded “`(no tasks in flight)`” row.

**Accurate state reads (Firstmate-specific)**

- Does **not** trust `tail` of `state/<id>.status` as current state.
- Invokes sibling `bin/fm-crew-state.sh <id>`, which reconciles:
  1. Matching **no-mistakes run-step** for the crew’s branch (authoritative when present),
  2. Pane busy-signature (backend-aware),
  3. Status-log verb only as fallback, with supersession when the run moved on.
- Parses one-line contract:  
  `state: <word> · source: <run-step|pane|status-log|none> · <optional note>`  
  → dashboard columns **STATE** + truncated note.
- Header comment on the dashboard still mentions an older “cheap meta+log only” design; the body comments and code use per-task `fm-crew-state` (slower compose, flicker-free paint of the **finished** frame).

**Frame composition (reusable)**

- `compose` writes a full frame line-by-line.
- Every line is **padded to terminal width** (`printf '%-*.*s' cols cols`) so a shorter new line overwrites a longer previous one with no leftovers.
- Colors only when stdout is a TTY; stripped otherwise.

**Flicker-free repaint (reusable — proven rule #1)**

```text
printf '\033[H'     # cursor home
compose             # full padded frame
printf '\033[0J'    # clear from cursor to end of screen
```

- **Never** `\033[2J` (full clear) on every tick — that blanks the screen and causes visible flash.
- Full clear only once at program entry.

**Refresh pacing (reusable — proven rule #2)**

- Loop uses `sleep "$INTERVAL"`, not `read -t` on stdin.
- Rationale: when stdout is a TTY but stdin is not (common for agent panes, pipes, `herdr agent start -- bash …`), `read -t` misbehaves or busy-spins; `sleep` is portable and quiet.

**Terminal sizing / cleanup**

- Width: `tput cols` else `$COLUMNS` else `80`.
- Cleanup trap: show cursor (`\033[?25h` / `tput cnorm`), newline, exit 0.

**Launch integration (Firstmate + Herdr-specific)**

- `bin/fm-dashboard-launch.sh` is idempotent session-start glue:
  - Skip if `FM_DASHBOARD_DISABLE=1`.
  - Soft-no-op if `herdr` missing or `HERDR_ENV!=1` (print “open … manually”).
  - If agent label `fm-validation` already listed → leave it.
  - Else: `herdr tab create --no-focus --label fm-validation`, then `herdr agent start fm-validation --no-focus --tab … -- bash dashboard interval`.
  - Fallback: create tab, `pane send-text` + Enter.
- Does not steal focus; never fails the surrounding session hard (exits 0 on soft failures).

**Test evidence**

```text
$ bash tests/fm-validation-dashboard.test.sh
PASS (a) empty fleet
PASS (b) one task rendered
PASS (c) crew-state note surfaced
```

Hermetic setup: throwaway `FM_HOME`, copied dashboard, fake sibling `fm-crew-state.sh`, synthetic `state/demo-x1.meta`.

Demo frame (fake state reader, synthetic metas; stripped ANSI):

```text
  FIRSTMATE  ·  validation dashboard   · refresh 4s · Ctrl-C to quit
--------------------------------------------------------------------------------
TASK             PROJECT         CREW   STATE
alpha-a1         demo-app        claude working        review (running)
beta-b2          other-lib       codex  parked         awaiting_approval
--------------------------------------------------------------------------------
  2 task(s) in flight · updated HH:MM:SS
```

### Minimum architecture to reproduce

```text
┌─────────────────────────────────────────────────────────┐
│  Launch surface (optional)                              │
│  - bare shell | tmux pane | herdr tab/agent | …         │
└───────────────────────────┬─────────────────────────────┘
                            │ once
                            ▼
┌─────────────────────────────────────────────────────────┐
│  Dashboard process                                      │
│  1. discover tasks (directory of records)               │
│  2. for each: accurate current-state read               │
│  3. compose full width-padded frame in memory/stream    │
│  4. repaint: CSI H + frame + CSI 0J                     │
│  5. sleep N seconds; repeat                             │
│  6. trap: restore cursor                                │
└─────────────────────────────────────────────────────────┘
```

**Reusable mechanics:** discovery interface, frame pad + home/clear-to-end, sleep pacing, TTY-aware colors, hide/restore cursor, single-frame mode for tests.

**Firstmate-specific helpers:** `FM_HOME` / `state/*.meta` schema, `fm-crew-state.sh` + no-mistakes + backend busy probes, `fm-dashboard-launch.sh` + Herdr agent label `fm-validation`.

---

## Recommendation

1. **Publish the multi-file gist** in section 2–3 below after firstmate (or captain) review. It is self-contained and does not require a live firstmate home.
2. Optionally **land** `fm-validation-dashboard.sh`, `fm-dashboard-launch.sh`, and the test into tracked firstmate via a normal ship task so `origin/main` matches the home that already runs them.
3. When shipping, fix the stale header comment on the dashboard (“cheap meta+log only”) so it matches the `fm-crew-state` body, or document the cost tradeoff explicitly.
4. Do **not** bake personal `FM_HOME` paths, live task IDs, or fleet dumps into the public gist (audit below).

---

# 1. Suggested gist title and description

**Title:**  
`Reproduce a flicker-free live terminal dashboard (Firstmate fm-validation pattern)`

**Description:**  
Minimal architecture and copyable Bash for a live multi-task validation/status TUI: discover records, read accurate state, compose a full width-padded frame, repaint with cursor-home + clear-to-end (no full-screen clear per tick), and pace with `sleep` (not `read -t` on a non-TTY). Includes a standalone demo and notes on which pieces are generic vs Firstmate-specific.

**Suggested visibility:** Public  
**Suggested files:**

| Filename | Role |
| --- | --- |
| `README.md` | Guide (primary) |
| `live-status-dashboard.sh` | Minimal portable reference implementation |
| `fake-state.sh` | Pluggable state reader used by the demo |
| `test-dashboard.sh` | Hermetic smoke tests for empty + multi-task frames |

---

# 2. Complete Markdown gist file (`README.md`)

```markdown
# Reproduce a flicker-free live terminal dashboard

This guide reverse-engineers Firstmate’s **`fm-validation`** live terminal dashboard so you can rebuild the same *observable* behavior in your own tooling.

It is written for operators and tool authors **outside** any one machine. It separates:

| Layer | Examples |
| --- | --- |
| **Reusable mechanics** | Frame pad, CSI home + clear-to-end, `sleep` pacing, TTY colors, trap cleanup |
| **Firstmate-specific helpers** | `state/*.meta`, `fm-crew-state.sh`, no-mistakes run-steps, Herdr `fm-dashboard-launch.sh` |

You do **not** need Firstmate installed to run the reference scripts in this gist.

---

## Prerequisites

- **Bash** 3.2+ (macOS stock Bash is fine) or Bash 4+/5
- A **TTY** for the live loop (or use single-frame mode for scripts/CI)
- Optional: `tput` (for columns / cursor hide; falls back to env / ANSI)
- Optional: any host that can run a long-lived process in a pane/tab (tmux, Herdr, Zellij, iTerm split, …)

No root, no cloud API, no tokens.

---

## What the dashboard does (observable behavior)

1. **Discovers** every in-flight task from a directory of small metadata files.
2. **Reads current state** for each task from an accurate reader (not a stale event log tail alone).
3. **Composes** one complete screenful: header, column labels, one row per task, footer with count + clock.
4. **Repaints without flicker**: move cursor home, write the whole frame, clear from cursor to end of screen.
5. **Waits** a fixed interval with `sleep`, then repeats until Ctrl-C.
6. **Restores** the cursor on exit.

On Firstmate, the accurate reader is `fm-crew-state.sh` (no-mistakes run-step first, then pane busy, then status-log fallback). In this gist, a **pluggable** `fake-state.sh` stands in so the render loop is independent.

---

## Proven rendering rules (do not “improve” these away)

### Rule 1 — Full padded frame, then home + clear-to-end

```bash
# once at startup (optional)
printf '\033[2J'

# every tick
printf '\033[H'    # cursor to top-left
compose_frame      # print full width-padded lines
printf '\033[0J'   # erase from cursor to end of display
```

**Why not clear the whole screen every tick?**  
`\033[2J` blanks everything first → a visible flash / empty frame.  
Home + overwrite + `\033[0J` keeps the previous pixels until the new frame is written, so the UI never “blinks black.”

**Why pad every line to terminal width?**  
If the new line is shorter than the old one, leftover characters from the previous frame remain. Padding with spaces to `cols` guarantees a full overwrite.

### Rule 2 — Pace with `sleep`, not `read -t`

```bash
while true; do
  render
  sleep "$INTERVAL"
done
```

**Why not `read -t "$INTERVAL"`?**  
Dashboards often run with stdin **not** connected to a keyboard (agent panes, `herdr agent start -- bash …`, CI). `read -t` on a non-TTY is unreliable; `sleep` always works.

---

## Minimum architecture

```
Task store          State reader           Frame composer          Painter
(meta files)   →   (one line/task)   →   (pad to width)   →   CSI H + body + CSI 0J
       ↑                                                              |
       └──────────────────── sleep(interval) ◄────────────────────────┘
```

| Concern | Portable approach | Firstmate concrete |
| --- | --- | --- |
| Task discovery | Glob records under a home dir | `$FM_HOME/state/*.meta` |
| Fields | id, project, worker, … | `project=`, `harness=`, … |
| Current state | Pluggable command | `fm-crew-state.sh <id>` |
| Event log | Never treat append-only log as sole current state | `state/<id>.status` is wake **events** |
| Launch | Manual or session hook | `fm-dashboard-launch.sh` → Herdr tab/agent `fm-validation` |
| Test mode | `ONCE=1` single frame | `FM_DASH_ONCE=1` |

---

## Implementation walkthrough

### 1. Task discovery

```bash
STATE_DIR="${HOME_DIR}/state"
shopt -s nullglob
metas=("$STATE_DIR"/*.meta)
shopt -u nullglob
```

Each meta file is key=value. Minimal keys for a row:

```text
project=/path/to/repo-or-name
harness=claude
kind=ship
```

Task id = filename stem (`demo-a1.meta` → `demo-a1`).  
Project column often uses `basename` of the project path.

### 2. Accurate state reads

**Portable contract** (one line stdout):

```text
state: <word> · source: <label> · <optional note>
```

Examples:

```text
state: working · source: run-step · review (running)
state: parked · source: run-step · awaiting_approval
state: unknown · source: none
```

**Firstmate note:** the real `fm-crew-state.sh` must not be replaced by `tail -1 status` in production: after a gate is answered, the last status line can still say `needs-decision` while the pipeline is already running again. The dashboard’s value is that it surfaces **current** validation progress.

### 3. Frame composition

- Detect width: `tput cols` → `$COLUMNS` → `80`.
- Pad helper: `printf '%-*.*s' "$cols" "$cols" "$line"`.
- Header: title + interval + quit hint.
- Columns: TASK / PROJECT / CREW / STATE (+ note).
- Footer: task count + `date +%H:%M:%S`.
- Color only when `[ -t 1 ]`.

### 4. Flicker-free repaint

See Rule 1. Compose and paint in one grouped write:

```bash
{ printf '\033[H'; compose; printf '\033[0J'; } 2>/dev/null
```

### 5. Refresh pacing

Default interval **4** seconds (tunable). `sleep` only.

### 6. Terminal sizing / cleanup

```bash
cleanup() { printf '\033[?25h'; tput cnorm 2>/dev/null || true; printf '\n'; exit 0; }
trap cleanup INT TERM
tput civis 2>/dev/null || printf '\033[?25l'
```

### 7. Launch integration (patterns)

| Host | Pattern |
| --- | --- |
| Bare terminal | `./live-status-dashboard.sh 4` |
| tmux | `tmux new-window -d -n status './live-status-dashboard.sh 4'` |
| Firstmate + Herdr | `fm-dashboard-launch.sh`: create dedicated tab with `--no-focus`, start agent labeled `fm-validation`, reuse if already listed; soft-exit if Herdr missing |

Idempotent launch principles:

1. Detect “already running” by a stable label.
2. Never steal focus from the operator pane.
3. Soft-fail (message + exit 0) when the preferred host is unavailable so session start never breaks.

### 8. Portability caveats

- **ANSI CSI** codes assume a VT-like terminal (macOS Terminal, iTerm2, most Linux TTYs, modern Windows Terminal). Dumb pipes still work in `ONCE` mode without color.
- **`tput`** may be missing in minimal containers; keep env/ANSI fallbacks.
- **Bashisms**: `BASH_SOURCE`, `shopt nullglob`, `$'\t'`. Rewrite carefully for pure POSIX if needed.
- **Width races**: resizing mid-frame can leave one dirty line; next tick repads. Acceptable for a 4s dashboard.
- **Slow state readers**: if state lookup takes > interval, frames simply update less often; double-buffer style (compose fully, then paint) still avoids flicker of *partial* frames.
- **Do not** use full-screen libraries unless you need mouse/widgets; the CSI approach is dependency-free.

---

## Setup and run (this gist)

```bash
chmod +x live-status-dashboard.sh fake-state.sh test-dashboard.sh

# Single frame (CI / copy-paste debug)
HOME_DIR=./demo-home ONCE=1 ./live-status-dashboard.sh

# Live loop (default 4s)
HOME_DIR=./demo-home ./live-status-dashboard.sh 2
# Ctrl-C to quit
```

Create a demo home:

```bash
mkdir -p demo-home/state
cat > demo-home/state/alpha-a1.meta <<'EOF'
project=/tmp/example-projects/demo-app
harness=claude
kind=ship
EOF
cat > demo-home/state/beta-b2.meta <<'EOF'
project=/tmp/example-projects/other-lib
harness=codex
kind=ship
EOF
```

Point the dashboard’s state reader at `fake-state.sh` (the reference script does this by default via `STATE_CMD`).

---

## Validation checks

Run:

```bash
./test-dashboard.sh
```

Expect:

- empty fleet → contains `no tasks in flight`
- one or more metas → ids, project basenames, harness names, and state words appear
- notes from the state reader appear when present
- no crash when `HOME_DIR` has zero metas

Manual live check:

1. Start the loop in a real terminal.
2. Confirm **no full-screen blink** each refresh.
3. Shorten a long note (edit fake state), confirm **no leftover characters** on that row.
4. Ctrl-C → cursor visible again.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Screen flashes black every tick | Full clear each frame | Use `\033[H` + frame + `\033[0J` only |
| Ghost characters at end of lines | Missing width pad | Pad every line to `cols` |
| High CPU / spin | `read -t` on non-TTY | Use `sleep` |
| Cursor permanently hidden | Missing trap | Restore `\033[?25h` on INT/TERM |
| All states `unknown` | State command wrong / not executable | Check `STATE_CMD` path and mode |
| Firstmate shows wrong “done” while validating | Used status log tail | Use `fm-crew-state` (run-step authoritative) |
| Herdr launch does nothing | Outside Herdr / disabled | `HERDR_ENV=1`, `herdr` on PATH; or run dashboard manually; `FM_DASHBOARD_DISABLE` |
| Colors in logs | Piped non-TTY still colored | Gate colors on `[ -t 1 ]` |

---

## Source references (Firstmate)

When you have a firstmate checkout that includes the dashboard (may be local-only until merged):

| Piece | Path |
| --- | --- |
| Live TUI | `bin/fm-validation-dashboard.sh` |
| Herdr auto-spawn | `bin/fm-dashboard-launch.sh` |
| Accurate state | `bin/fm-crew-state.sh` |
| Hermetic tests | `tests/fm-validation-dashboard.test.sh` |
| One-shot fleet table (non-live) | `bin/fm-fleet-view.sh` over `bin/fm-fleet-snapshot.sh` |
| Supervision / status log semantics | project `AGENTS.md` (status = wake events, not current state) |

Conceptual mapping:

| Gist name | Firstmate name |
| --- | --- |
| `live-status-dashboard.sh` | `fm-validation-dashboard.sh` |
| `STATE_CMD` / `fake-state.sh` | `fm-crew-state.sh` |
| `HOME_DIR` | `FM_HOME` |
| `ONCE=1` | `FM_DASH_ONCE=1` |
| Optional host launcher | `fm-dashboard-launch.sh` (`fm-validation` agent label) |

---

## License note

Treat this guide as documentation of a rendering pattern. Reuse freely. Firstmate itself remains under its own repository license.
```

---

# 3. Additional gist files (complete contents)

## `live-status-dashboard.sh`

```bash
#!/usr/bin/env bash
# live-status-dashboard.sh - portable flicker-free multi-task status TUI
# Pattern matching Firstmate's fm-validation-dashboard (compose + home + clear-to-end; sleep pacing).
#
# Usage:
#   HOME_DIR=./demo-home ./live-status-dashboard.sh [interval-seconds]
#   ONCE=1 HOME_DIR=./demo-home ./live-status-dashboard.sh
#
# Env:
#   HOME_DIR   directory containing state/*.meta  (default: parent of this script)
#   STATE_CMD  executable that prints "state: WORD · source: S · NOTE" for id $1
#              (default: sibling fake-state.sh if present)
#   ONCE=1     single frame then exit
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME_DIR:-$(cd "$SCRIPT_DIR" && pwd)}"
STATE_DIR="$HOME_DIR/state"
INTERVAL="${1:-4}"
STATE_CMD="${STATE_CMD:-$SCRIPT_DIR/fake-state.sh}"

if [ -t 1 ]; then
  R=$'\033[0m'; DIM=$'\033[2m'; B=$'\033[1m'
  CY=$'\033[36m'; GN=$'\033[32m'; YE=$'\033[33m'; RE=$'\033[31m'; GY=$'\033[90m'
else
  R=; DIM=; B=; CY=; GN=; YE=; RE=; GY=
fi

cleanup() { printf '\033[?25h'; tput cnorm 2>/dev/null || true; printf '\n'; exit 0; }
trap cleanup INT TERM

term_cols() { tput cols 2>/dev/null || echo "${COLUMNS:-80}"; }

meta_field() { grep -m1 "^$2=" "$1" 2>/dev/null | cut -d= -f2-; }

status_word_note() { # <id> -> "word\tnote"
  local line word note
  if [ -x "$STATE_CMD" ] || [ -f "$STATE_CMD" ]; then
    line="$("$STATE_CMD" "$1" 2>/dev/null || true)"
  else
    line="state: unknown · source: none · no STATE_CMD"
  fi
  word="$(printf '%s' "$line" | sed -n 's/^state: *\([a-z-]*\).*/\1/p')"
  note="$(printf '%s' "$line" | sed -n 's/.*· \([^·]*\)$/\1/p')"
  [ -z "$word" ] && word="unknown"
  printf '%s\t%s' "$word" "$note"
}

color_for() {
  case "$1" in
    done|passed|merged) printf '%s' "$GN" ;;
    needs-decision|blocked|paused|resolved|parked) printf '%s' "$YE" ;;
    failed|stale) printf '%s' "$RE" ;;
    working|validating) printf '%s' "$CY" ;;
    *) printf '%s' "$R" ;;
  esac
}

compose() {
  local cols now line
  cols="$(term_cols)"
  now="$(date '+%H:%M:%S')"
  pad() { printf '%-*.*s' "$cols" "$cols" "$1"; }

  pad "$(printf '%s  STATUS  ·  live dashboard   %s· refresh %ss · Ctrl-C to quit' "$B$CY" "$DIM" "$INTERVAL")$R"; printf '\n'
  pad "$GY$(printf '%*s' "$cols" '' | tr ' ' '-')$R"; printf '\n'
  pad "$(printf '%s%-16s %-15s %-6s %s%s' "$DIM" 'TASK' 'PROJECT' 'CREW' 'STATE' "$R")"; printf '\n'

  shopt -s nullglob; local metas=("$STATE_DIR"/*.meta); shopt -u nullglob
  if [ ${#metas[@]} -eq 0 ]; then
    pad "$DIM  (no tasks in flight)$R"; printf '\n'
    return
  fi

  local m id project crew sw word note col n=0
  for m in "${metas[@]}"; do
    id="$(basename "$m" .meta)"
    project="$(basename "$(meta_field "$m" project)" 2>/dev/null)"
    crew="$(meta_field "$m" harness)"
    [ -z "$crew" ] && crew="-"
    [ -z "$project" ] && project="-"
    sw="$(status_word_note "$id")"
    word="${sw%%$'\t'*}"; note="${sw#*$'\t'}"
    col="$(color_for "$word")"
    line="$(printf '%-16s %-15s %-6s %s%-14s%s %s%s%s' \
      "${id:0:16}" "${project:0:15}" "${crew:0:6}" \
      "$col" "$word" "$R" "$DIM" "${note:0:$((cols>60?cols-55:20))}" "$R")"
    pad "$line"; printf '\n'
    n=$((n + 1))
  done
  pad "$GY$(printf '%*s' "$cols" '' | tr ' ' '-')$R"; printf '\n'
  pad "$DIM  $n task(s) in flight · updated $now$R"; printf '\n'
}

render() {
  # Home cursor, paint composed frame, clear to end. Never full-clear each tick.
  { printf '\033[H'; compose; printf '\033[0J'; } 2>/dev/null
}

if [ "${ONCE:-0}" = "1" ]; then compose; exit 0; fi

printf '\033[2J'
tput civis 2>/dev/null || printf '\033[?25l'
while true; do
  render
  sleep "$INTERVAL"
done
```

## `fake-state.sh`

```bash
#!/usr/bin/env bash
# fake-state.sh - demo stand-in for Firstmate's fm-crew-state.sh
# Prints one parseable line: state: WORD · source: LABEL · note
set -u
id="${1:-}"
case "$id" in
  alpha-a1) echo "state: working · source: demo · review (running)" ;;
  beta-b2)  echo "state: parked · source: demo · awaiting_approval" ;;
  demo-x1)  echo "state: validating · source: demo · doing the thing (running)" ;;
  *)        echo "state: unknown · source: demo · no sample for ${id:-?}" ;;
esac
```

## `test-dashboard.sh`

```bash
#!/usr/bin/env bash
# Hermetic smoke tests for live-status-dashboard.sh (ONCE mode).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASH="$ROOT/live-status-dashboard.sh"
fail=0
strip() { sed 's/\x1b\[[0-9;?]*[A-Za-z]//g'; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/state"
cp "$DASH" "$ROOT/fake-state.sh" "$work/" 2>/dev/null || true
cp "$DASH" "$work/live-status-dashboard.sh"
cp "$ROOT/fake-state.sh" "$work/fake-state.sh"
chmod +x "$work/live-status-dashboard.sh" "$work/fake-state.sh"

# (a) empty fleet
out="$(ONCE=1 HOME_DIR="$work" "$work/live-status-dashboard.sh" 2>&1 | strip)"
if printf '%s' "$out" | grep -q "no tasks in flight"; then
  echo "PASS (a) empty fleet"
else
  echo "FAIL (a) empty fleet: $out"; fail=1
fi

# (b)+(c) one task
cat > "$work/state/demo-x1.meta" <<'META'
project=/tmp/example-projects/sample-app
harness=grok
kind=ship
META
out="$(ONCE=1 HOME_DIR="$work" STATE_CMD="$work/fake-state.sh" "$work/live-status-dashboard.sh" 2>&1 | strip)"
if printf '%s' "$out" | grep -q "demo-x1" \
   && printf '%s' "$out" | grep -q "sample-app" \
   && printf '%s' "$out" | grep -q "grok" \
   && printf '%s' "$out" | grep -q "validating"; then
  echo "PASS (b) one task rendered"
else
  echo "FAIL (b) one task: $out"; fail=1
fi
if printf '%s' "$out" | grep -q "doing the thing"; then
  echo "PASS (c) state note surfaced"
else
  echo "FAIL (c) note: $out"; fail=1
fi

exit "$fail"
```

### Optional fifth file (not required)

If the publisher wants a pure reference of Firstmate’s launcher *without* running Herdr lifecycle from the gist, a short `LAUNCH-NOTES.md` is enough (prefer notes over a copy-paste Herdr script, since Herdr CLI flags vary by version):

```markdown
# Launch notes (Firstmate + Herdr)

Firstmate’s `fm-dashboard-launch.sh` is **host glue**, not part of the TUI algorithm:

1. Skip when `FM_DASHBOARD_DISABLE=1`.
2. Require `herdr` on PATH and `HERDR_ENV=1`; otherwise print “open dashboard manually” and exit 0.
3. If agent list already contains label `fm-validation`, exit 0 (idempotent).
4. `herdr tab create --no-focus --label fm-validation --cwd "$FM_HOME"`.
5. `herdr agent start fm-validation --no-focus --tab <tab_id> --cwd "$FM_HOME" -- bash fm-validation-dashboard.sh <interval>`.
6. Fallback: create tab, send the shell command into the pane, send Enter.

For tmux-only fleets, skip this file and open `live-status-dashboard.sh` in a dedicated window yourself.
```

---

# 4. Secrets / privacy audit

| Check | Result |
| --- | --- |
| Personal absolute paths in draft content | **None** — examples use `/tmp/example-projects/…`, `./demo-home`, `$FM_HOME` placeholders |
| Live fleet task IDs | **None** — demos use `alpha-a1`, `beta-b2`, `demo-x1` only |
| Tokens / `.env` / pairing keys | **None** |
| Captain preferences / backlog / projects registry | **Not included** |
| Real PR URLs / private repo names | **None** |
| Primary home username paths in *gist body* | **Stripped** — report meta may mention scout paths for firstmate; **do not paste the “What I did” section into the public gist** — only sections 1–3 file bodies |
| Test fixture path from upstream test (`/Users/x/projects/k-zero`) | Replaced with `/tmp/example-projects/sample-app` in gist test |
| Herdr lifecycle destructive commands | **Not** included as a runnable gist script; launch notes are descriptive only |

**Publish checklist for firstmate**

1. Create gist with the four files (or five with `LAUNCH-NOTES.md`) from section 2–3 only.  
2. Do not attach this full scout report, status logs, or `state/*.meta` dumps.  
3. Confirm `gh gist create` dry-run content has no `leebarry` / machine-local paths.  
4. Optional: after merge of dashboard scripts to firstmate `main`, add a one-line upstream link in the gist README.

---

## Evidence summary (commands)

| Command / action | Result |
| --- | --- |
| Worktree `ls bin/fm-validation*` | Missing on `origin/main` worktree |
| Read primary `bin/fm-validation-dashboard.sh` | 110 lines; compose/render/sleep contract |
| Read primary `bin/fm-dashboard-launch.sh` | 51 lines; Herdr idempotent launch |
| Read primary `tests/fm-validation-dashboard.test.sh` | 61 lines; three cases |
| `bash tests/fm-validation-dashboard.test.sh` | PASS a/b/c |
| Synthetic two-task `FM_DASH_ONCE=1` frame | Table rows + notes as expected |
| `git status` on primary for dashboard paths | untracked `??` (not yet shipped) |

## Conclusion

The live dashboard is a small, well-factored Bash loop: **discover metas → accurate state per task → width-padded full frame → cursor-home + clear-to-end → sleep**. The two non-negotiable rendering rules are fully portable; Firstmate’s accuracy comes from plugging in `fm-crew-state` instead of a status-log tail, and its docking comes from Herdr-specific launch glue. The multi-file gist draft above is ready for human review and publish; this scout did not create or upload a gist.
