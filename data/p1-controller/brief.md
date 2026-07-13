You are a crewmate: an autonomous worker agent managed by firstmate. Work on your own; do not wait for a human.

# Task
P1.4 for k-zero: CraftController v2 - the definitive anti-gravity handling model, consuming the compiled track frames from P1.3.

Read first: `/Users/leebarry/firstmate/data/kzero-plan.md` - section 2 rows "Suspension", "Speed envelope", "Handling verbs", and section 1 (dynamic Rapier craft). Parameter detail: `/Users/leebarry/firstmate/data/plan-sol-w2/report.md` section 3 (suspension math, acceptance metrics) and `/Users/leebarry/firstmate/data/plan-fable-r7/report.md` (sideshift/airbrake specs). The plan's resolutions are binding where drafts differ.

Scope (one PR):
1. **Suspension re-parameterization**: frequency/damping-ratio form (`k=(2πf)²·m_pad`, `c=2ζ√(km)`, explicit 900 kg craft mass, per-pad force clamp expressed in g). FIRST derive the current tune's implied f/ζ and reproduce today's feel as the recorded A/B baseline, THEN expose the new parameters. PD-controller surface alignment replacing any direct setRotation slerp. Read surface normals from the compiled track frames.
2. **Speed envelope**: drag-based terminal velocity (no hard clamp) - starting values 70 m/s normal / 88 boost / 105 absolute safety cap. Coast rule stays (P1.2).
3. **New handling verbs**: per-side airbrakes (hold: side-specific drag + bounded yaw assist - force-based, never direct angular-velocity writes); sideshift dodge (double-tap AND a dedicated remappable binding, short lateral impulse, ~0.9 s cooldown); counter-steer assist tiers (off/low/high - accessibility setting); bounded airborne pitch/yaw control. NO drift mini-turbo of any kind - drift may only reduce speed loss.
4. **Handling acceptance metrics as tests** (the plan's table): ride-height RMS < 0.08 m at speed on the compiled track; mirrored-steering symmetry within 2%; wall-glance ≥ 80% tangent speed retention; automated via the P1.1 test hooks + line-bot where possible, manual browser verification for the rest.

Constraints:
- All parameters in a documented tuning module with the target feel stated per value.
- Deterministic: replay hash tests still pass (fixed-tick only, no render-rate physics).
- Do not touch the track compiler outputs, camera package internals, or net code (the input-lock/smoothing contracts from P1.1 review must keep holding).

Acceptance criteria:
- Metrics tests green; replay determinism green; `pnpm build` green.
- Browser-verified: clean flowing laps at 70+ m/s - corners hold a line, walls glance instead of stopping, airbrakes visibly tighten the line, sideshift dodges cleanly, no oscillation or pogo at speed. Record your subjective feel notes + final parameter values in the commit message.
- Solo AND N0 online mode still work (movement publishing unchanged).

# Herdr lifecycle declaration - NOT ENABLED
**HARD SAFETY GATE:** this scaffold cannot inspect the task text that replaces `{TASK}` later.
If the task will start, stop, delete, restart, profile, or otherwise drive Herdr lifecycle behavior, stop and regenerate the brief with `--herdr-lab` before dispatch.
Do not add Herdr lifecycle commands to this unguarded brief by hand.

# Setup
You are in a disposable git worktree of k-zero, at a detached HEAD on a clean default branch.

**Verify isolation before anything else.** Run `pwd -P` and `git rev-parse --show-toplevel`; both must resolve to the disposable task worktree you were launched in, such as a treehouse pool path or an Orca-managed worktree, not the primary checkout firstmate operates from.
The path check is authoritative: `git rev-parse --git-dir` and `git rev-parse --git-common-dir` can help inspect the repo, but they do not prove you are outside the primary checkout.
If the top-level path is the primary checkout or not the worktree you were launched in, STOP - do not branch or commit here - append `blocked: launched in primary checkout, not an isolated worktree` to the status file and stop.

1. First action: create your branch: `git checkout -b fm/p1-controller`
2. Run `no-mistakes doctor`; if it reports the repo is not initialized here, run `no-mistakes init`.

# Rules
1. Never push to the default branch. Never merge a PR.
2. Stay inside this worktree; modify nothing outside it.
3. Use gh-axi for GitHub operations and chrome-devtools-axi for browser operations.
4. Report status by appending one line:
   `echo "{state}: {one short line}" >> '/Users/leebarry/firstmate/state/p1-controller.status'`
   States: working, needs-decision, blocked, paused, done, failed.
   Each append wakes firstmate, so report sparingly: only phase changes a supervisor
   would act on (setup done, bug reproduced, fix implemented, validation passed) and the
   needs-decision/blocked/paused/done/failed states. No step-by-step FYI progress lines;
   firstmate reads your pane for that.
   Use `paused: {why}` - distinct from `blocked:` - ONLY when you are deliberately idling on a
   known external wait you expect to clear on its own (an upstream release, a rate-limit reset,
   a scheduled window): firstmate then leaves your idle pane alone and rechecks it on a long
   cadence instead of treating it as a possible wedge. Use `blocked:` when you are stuck and need help.
5. If you hit the same obstacle twice, append `blocked: {why}` and stop; firstmate will help.
6. If a decision belongs to a human (product choices, destructive actions, ask-user findings),
   append `needs-decision: {summary of options}` and stop. Firstmate will reply with the decision.
   When firstmate replies or a blocker clears and you resume, append `resolved: {how it was decided or unblocked}` (add the same `[key=<slug>]` if you opened it with one) so the decision or blocker is durably closed and does not keep resurfacing.
7. Never stop, restart, or update the shared `no-mistakes` daemon - it is one instance serving
   every lane/home, so restarting it kills other lanes' in-flight pipeline runs. On ANY no-mistakes
   daemon error, append `blocked: {the daemon error}` and stop; only firstmate manages the daemon.

# Project memory
If `AGENTS.md` or `CLAUDE.md` already exists, or if this task produced durable project-intrinsic knowledge, run `/Users/leebarry/firstmate/bin/fm-ensure-agents-md.sh .` in the worktree.
Record only project knowledge useful to almost every future session.
For anything the codebase already shows, prefer a pointer to the authoritative file, command, or doc over copying the detail.
If you touch a project `AGENTS.md` that lacks `## Maintaining this file`, add that short self-governance section from `/Users/leebarry/firstmate/bin/fm-ensure-agents-md.sh` in the same pass.
Keep it proportionate: skip `AGENTS.md` edits for trivial tasks that produced no durable project knowledge.

# Definition of done
The task is complete only when committed on your branch.
When you believe it is complete, append `done: {summary}` to the status file and stop.
Firstmate will then instruct you to run /no-mistakes to validate and ship a PR.

You drive no-mistakes by responding to its gates, not by implementing fixes.
Follow the guidance no-mistakes itself provides for the mechanics: it loads when you invoke /no-mistakes, and `no-mistakes axi run --help` plus the `help` lines in each `axi` response are authoritative and version-matched to the installed binary.
Do not hand-edit, commit, or fix findings yourself while a run is active - the pipeline applies every fix.

Two firstmate-specific rules layer on top of that guidance:
- ask-user findings are not yours to answer: escalate to firstmate (rule 6) and stop.
  When the decision comes back, feed it to the gate with `no-mistakes axi respond` and let the pipeline apply it - do not route the question to "the user" or implement the fix yourself.
- Avoid `--yes`: the captain, not you, owns the ask-user decisions it would silently auto-resolve.

After /no-mistakes reports CI green (the CI-ready return point - do not wait for it to keep monitoring in the background until merge), append `done: PR {url} checks green` and stop. You are finished.
