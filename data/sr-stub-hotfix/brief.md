You are a crewmate: an autonomous worker agent managed by firstmate. Work on your own; do not wait for a human.

# Task
SAFETY HOTFIX for service-referral (captain-priority, found by two independent audits): when AI evaluation FAILS or returns the zero-confidence stub, the UI renders a green "Accept" recommendation badge and PRESELECTS "Accept" in the human decision form. Evidence: /Users/leebarry/firstmate/data/sr-plan-f3/screenshots/14-referral-accept-testla.png - confidence 0%, every gate not_assessed, "insufficient information", yet a green Accept badge and Accept preselected. This converts a schema fallback into apparent clinical/commercial advice and makes agreement the path of least resistance in a CQC-regulated, special-category-data product.

Root cause pointers (verified by the audits): the evaluation fallback constructs `decision: "accept"` on unexpected failure (src/lib/jobs/evaluate.ts around lines 103-113); the pipeline stores it as the current recommendation (src/lib/jobs/pipeline.ts around 588-606); review-reason codes live only in event detail. There is also a threshold inconsistency: the engine's configurable 0.65 review threshold vs a hard-coded 0.6 fallback in src/lib/jobs/evaluate.ts around line 118.

Scope - a TIGHT hotfix to the CURRENT UI (a ground-up rebuild is separately planned; do NOT start it, do NOT add new tables):
1. A single server-side presenter/guard used by queue, detail, form, and any report/export surface: whenever evaluation state is failed/indeterminate (zero-confidence stub signature, requiresHumanReview-with-no-basis, or evaluation_failed), the recommendation presents as NONE - render "No recommendation - insufficient information / evaluation failed" (amber/neutral, never green), never the stubbed accept.
2. Remove decision PRESELECTION for EVERY outcome, not just stubs - the human decision control starts unselected always; submitting requires an explicit choice.
3. Unify the review threshold: one configured source (EVAL_CONFIDENCE_THRESHOLD) consumed everywhere; delete the hard-coded 0.6.
4. Tests: unit tests for the presenter across accept/conditional/decline/failed/stub; a regression test fixture reproducing the screenshot-14 state (zero-confidence stub) asserting no accept badge and no preselection; threshold unification test.
5. Do NOT alter the frozen ReferralExtract/RecommendationResult contracts, the evaluation engine behavior, or stored data. Presentation + threshold only.

Acceptance: all tests green, lint/build green, screenshot-14 scenario shows the no-recommendation state in queue AND detail AND decision form, no preselected decision anywhere in the app.

# Herdr lifecycle declaration - NOT ENABLED
**HARD SAFETY GATE:** this scaffold cannot inspect the task text that replaces `{TASK}` later.
If the task will start, stop, delete, restart, profile, or otherwise drive Herdr lifecycle behavior, stop and regenerate the brief with `--herdr-lab` before dispatch.
Do not add Herdr lifecycle commands to this unguarded brief by hand.

# Setup
You are in a disposable git worktree of service-referral, at a detached HEAD on a clean default branch.

**Verify isolation before anything else.** Run `pwd -P` and `git rev-parse --show-toplevel`; both must resolve to the disposable task worktree you were launched in, such as a treehouse pool path or an Orca-managed worktree, not the primary checkout firstmate operates from.
The path check is authoritative: `git rev-parse --git-dir` and `git rev-parse --git-common-dir` can help inspect the repo, but they do not prove you are outside the primary checkout.
If the top-level path is the primary checkout or not the worktree you were launched in, STOP - do not branch or commit here - append `blocked: launched in primary checkout, not an isolated worktree` to the status file and stop.

1. First action: create your branch: `git checkout -b fm/sr-stub-hotfix`
2. Run `no-mistakes doctor`; if it reports the repo is not initialized here, run `no-mistakes init`.

# Rules
1. Never push to the default branch. Never merge a PR.
2. Stay inside this worktree; modify nothing outside it.
3. Use gh-axi for GitHub operations and chrome-devtools-axi for browser operations.
4. Report status by appending one line:
   `echo "{state}: {one short line}" >> '/Users/leebarry/firstmate/state/sr-stub-hotfix.status'`
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
