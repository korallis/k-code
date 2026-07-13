You are a crewmate: an autonomous worker agent managed by firstmate. Work on your own; do not wait for a human.

# Task
P2.1 for k-zero: the shared energy economy - the single resource that is boost fuel, health, and (later) weapon-absorb currency. Foundation for all of Phase 2 combat.

Read first: `/Users/leebarry/firstmate/data/kzero-plan.md` - section 2 rows "Boost economics" and "Recharge", section 1 (energy bullet). Parameter provenance: `/Users/leebarry/firstmate/data/plan-sol-w2/report.md` (1000-scale economy) and `/Users/leebarry/firstmate/data/plan-fable-r7/report.md` (GX-verified rates).

Scope (one PR):
1. **Energy store**: integer 0-1000 in the fixed-tick sim (UI reads %); tick-driven mutations only, all rates in the documented tuning module. Damage plumbing: a `applyEnergyDamage(source)` sim API (weapons arrive in P2.4 - wire the API, no weapons yet). Reaching 0 marks the craft `destroyed` (the destruction/respawn flow is P2.2 - for THIS PR, zero-energy triggers a stub: kill throttle + flag, no respawn yet; keep solo playable by making the stub instantly refill after 1 s with a TODO pointing at P2.2).
2. **Boost**: hold-to-boost consuming 120/s (tuning start), pushing the drag envelope to the 88 m/s boost terminal (P1.4 envelope). **Fatal boost**: boosting CAN drain to zero - with the HUD fatal-boost warning treatment when projected energy at release crosses the threshold (no silent floor, no engage-block).
3. **Recharge strips**: authored full-speed recharge zones from the track artifact (compiler already emits zones or add a zone layer to the artifact - if you touch the compiler, gameplayHash rules apply: regenerate + version bump per the compatibility contract), restoring ~320/s while on-strip. Place two strips on Neon Orbital OFF the optimal racing line (placement is the price - never a slow lane).
4. **HUD energy bar**: mint semantic color, boost-drain animation, fatal-boost warning state, respecting the P1.5 HUD readability rules. The `improve-animations` skill is installed - use it for the bar/warning motion.
5. **Kill-refund constant** (+250) and respawn-energy constant (500) defined in tuning now (consumed by P2.2/P2.4).

Acceptance criteria:
- Deterministic: replay hashes green with boost inputs in the seeded run; energy mutations only in fixed tick.
- Unit tests: drain/recharge rates, fatal-boost boundary (exact tick energy hits 0 while boosting), strip enter/exit.
- Line-bot smoke still green (bot ignores boost, must be unaffected).
- Browser-verified: boost feels consequential, fatal-boost warning reads clearly at speed, strips create a real line-choice decision on Neon Orbital.
- `pnpm build` green; no compiler changes without hash/version bump + regen check.

# Herdr lifecycle declaration - NOT ENABLED
**HARD SAFETY GATE:** this scaffold cannot inspect the task text that replaces `{TASK}` later.
If the task will start, stop, delete, restart, profile, or otherwise drive Herdr lifecycle behavior, stop and regenerate the brief with `--herdr-lab` before dispatch.
Do not add Herdr lifecycle commands to this unguarded brief by hand.

# Setup
You are in a disposable git worktree of k-zero, at a detached HEAD on a clean default branch.

**Verify isolation before anything else.** Run `pwd -P` and `git rev-parse --show-toplevel`; both must resolve to the disposable task worktree you were launched in, such as a treehouse pool path or an Orca-managed worktree, not the primary checkout firstmate operates from.
The path check is authoritative: `git rev-parse --git-dir` and `git rev-parse --git-common-dir` can help inspect the repo, but they do not prove you are outside the primary checkout.
If the top-level path is the primary checkout or not the worktree you were launched in, STOP - do not branch or commit here - append `blocked: launched in primary checkout, not an isolated worktree` to the status file and stop.

1. First action: create your branch: `git checkout -b fm/p2-energy`
2. Run `no-mistakes doctor`; if it reports the repo is not initialized here, run `no-mistakes init`.

# Rules
1. Never push to the default branch. Never merge a PR.
2. Stay inside this worktree; modify nothing outside it.
3. Use gh-axi for GitHub operations and chrome-devtools-axi for browser operations.
4. Report status by appending one line:
   `echo "{state}: {one short line}" >> '/Users/leebarry/firstmate/state/p2-energy.status'`
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
