You are a crewmate: an autonomous worker agent managed by firstmate. Work on your own; do not wait for a human.

# Task
AAA environment + track-surface pass for k-zero: make the world look and feel like a AAA game (captain priority). Builds on the just-merged Tripo hero-asset round (PR #15) - the API asset pipeline is live (25k credits, ~280 spent so far; TRIPO_API_KEY via op read "op://Dev-Env/h4vrivdhvlrkjmwgnpacbwko6i/credential", website fallback).

Read first: `/Users/leebarry/firstmate/data/kzero-plan.md` (Art/HUD, Tracks, Performance rows) and the BINDING captain quality bar in `/Users/leebarry/firstmate/data/learnings.md` ("AAA and genuinely FUN", "pilot the ship" QA, universal BRB). Load threejs-aaa-graphics-builder (scorecard, env kit) and threejs-3d-generator (Tripo).

Scope (one PR - visual/scene, no sim/physics/gameplay logic):
1. **Track-surface life on BOTH tracks (Neon Orbital + Black Rain Foundry)**: make boost pads / recharge strips visibly present ON THE FLOOR (emissive surface treatment, chevrons, glow) so the player can see them while driving; surface detail/texturing so the track reads as a real surface not a flat ribbon; pickup pads glowing in their family colors; start/finish line treatment; lane/edge markings that aid the readability corridor.
2. **Environment kit generation + placement**: Tripo-generate + place the cyberpunk set dressing per the plan's layer contract - near-field pylons/gantries (optic flow at speed), mid-field building shells with emissive signage, far-field skyline + one landmark per sector, holo-billboards (never occluding the next 2 s of track). Foundry gets its rain/industrial variant; Neon Orbital its synthwave set.
3. **Atmosphere**: skybox/HDRI per track mood, fog/depth cueing (readability-safe), the neon/emissive lighting that sells cyberpunk - WITHOUT breaking the 60-120 m sightline corridor or track-vs-background hue separation.
4. Optional surface hazards/bumps ONLY if visual-and-cosmetic (no physics changes this PR - gameplay hazards are a later combat/level task); if you add any surface geometry that would affect the collider, STOP and leave it for a gameplay task.

Constraints:
- VISUAL ONLY: do not touch colliders, the track artifact gameplay data (gameplayHash must not change - if a change is truly needed, isolate + bump + regen + track:validate), physics, sim, weapons, or AI. Craft transform contract preserved.
- Tier-A budgets BINDING (<=180 draws / <=900k tris / <=256 MB textures): measure before/after on BOTH tracks worst view, record in PR; instancing for repeated props, LODs mid-field+. Report Tripo credits spent + remaining.
- Provenance manifest entry per generated asset.

Acceptance criteria (per the binding bar):
- PILOTED browser verification on BOTH tracks: actually drive a lap with real inputs and confirm the world reads as AAA at 70-88 m/s - boost pads visible underfoot, set dressing gives speed sensation, landmarks orient, no readability loss, stable 60fps.
- Run the running-bug-review-board pass on the running game (drive it) - no P0 visual/perf defects.
- pnpm build + line-bot smoke + replay determinism green (visual-only); budgets inside Tier A on both tracks; scorecard + provenance in the PR.

# Herdr lifecycle declaration - NOT ENABLED
**HARD SAFETY GATE:** this scaffold cannot inspect the task text that replaces `{TASK}` later.
If the task will start, stop, delete, restart, profile, or otherwise drive Herdr lifecycle behavior, stop and regenerate the brief with `--herdr-lab` before dispatch.
Do not add Herdr lifecycle commands to this unguarded brief by hand.

# Setup
You are in a disposable git worktree of k-zero, at a detached HEAD on a clean default branch.

**Verify isolation before anything else.** Run `pwd -P` and `git rev-parse --show-toplevel`; both must resolve to the disposable task worktree you were launched in, such as a treehouse pool path or an Orca-managed worktree, not the primary checkout firstmate operates from.
The path check is authoritative: `git rev-parse --git-dir` and `git rev-parse --git-common-dir` can help inspect the repo, but they do not prove you are outside the primary checkout.
If the top-level path is the primary checkout or not the worktree you were launched in, STOP - do not branch or commit here - append `blocked: launched in primary checkout, not an isolated worktree` to the status file and stop.

1. First action: create your branch: `git checkout -b fm/kz-environment`
2. Run `no-mistakes doctor`; if it reports the repo is not initialized here, run `no-mistakes init`.

# Rules
1. Never push to the default branch. Never merge a PR.
2. Stay inside this worktree; modify nothing outside it.
3. Use gh-axi for GitHub operations and chrome-devtools-axi for browser operations.
4. Report status by appending one line:
   `echo "{state}: {one short line}" >> '/Users/leebarry/firstmate/state/kz-environment.status'`
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
