You are a crewmate: an autonomous worker agent managed by firstmate. Work on your own; do not wait for a human.

# Task
Draft the k-zero TRANSFORMATION PLAN: turning the game into a full 3D battle racer where everything is fully 3D rendered with generated assets and the result is stunning, beautiful, and on par with the captain's reference class - Forza Motorsport, GTA 5, Spider-Man - pushed to the boundary of what browser rendering allows. This is a PLANNING scout: read deeply, research thoroughly, produce a plan document, write NO implementation code.

You are one of TWO independent planners drafting in parallel (the other uses a different model). After both drafts land, firstmate relays the other draft to you for cross-review; your claims will be attacked line-by-line, so ground everything in the actual code and captured evidence.

Captain context (binding):
- Current state REJECTED: ships "polygate" (suspect: the meshopt force-recompress/quantization pass corrupting geometry, plus LOD popping), floor pickups/drops and other assets are NOT generated models, overall look reads "like an old Amiga". A forensic visual audit (kz-visaudit-v7) is capturing 1080p evidence, polygating root-cause, a provenance violation inventory, and a renderer-lever inventory - its report will land at /Users/leebarry/firstmate/data/kz-visaudit-v7/report.md while you draft; INCORPORATE it when it appears (firstmate will also nudge you).
- TOTAL COVERAGE DOCTRINE: every visible thing is a real Tripo-generated 3D asset (API primary - TRIPO_API_KEY via `op read "op://Dev-Env/h4vrivdhvlrkjmwgnpacbwko6i/credential"`, ~24k credits available; Tripo web fallback). No primitive/procedural stand-ins, no exceptions for anything player-visible.
- CONTROLS: steering is "too finicky - too responsive in terms of left and right." Control feel is a first-class workstream: input smoothing/filtering, steering response curves, speed-sensitive steering, deadzone/ramp tuning - buttery smooth, verified by piloted feel-rating with evidence.
- Quality gates unchanged: no-mistakes + BRB with evidence artifacts (screenshots for visual claims, input+telemetry for piloting claims) on every landing PR. 60fps stays non-negotiable alongside the visual bar (stunning AND smooth).
- The captain may supply more reference examples mid-draft; firstmate will relay them.

Research requirement: use the Ref and Exa MCP research tools (registered in your harness) plus the threejs-aaa-graphics-builder / threejs-game-director skills (installed user-level) to ground the rendering strategy in the current state of the art: three.js WebGPURenderer/TSL vs WebGL2 path, HDR + tone mapping, PBR + IBL, shadow strategies, post chains (TAA/SSAO/bloom/motion blur), meshopt/quantization SAFE settings, texture budgets/KTX2, instancing/LOD without popping. Cite what you rely on.

The plan must cover, with concrete module/file-level detail against the actual repo:
1. Render pipeline transformation: current renderer state -> target AAA pipeline (renderer choice, color/HDR pipeline, lighting rig, shadows, post-processing chain, DPR/resolution strategy), with fallback tiers so 60fps holds.
2. Asset transformation program: per visible category (8 ships, pickups/drops, pads/strips, projectiles/impacts, props/structures, track surfaces, skybox/vistas) - generate/regenerate via Tripo, SAFE optimization settings that never corrupt geometry (fix the polygating class permanently, with a visual-diff verification step per asset), LODs without popping, texture quality targets, provenance manifest.
3. Control-feel workstream: diagnose the twitchy steering in the actual input/controller code, propose the smoothing/curve architecture, define piloted feel-acceptance criteria.
4. Stability: crash-free soaks, fall-through stress regression, frame-time consistency verification (series, not averages).
5. Reconciliation of the existing k-zero roadmap (queued AI-combat, multiplayer, production, release items and the smooth-gate/N0-fix tasks) into the transformation program - what folds in, what reorders, what dies.
6. Milestones sized for single-PR increments, parallelized by file ownership wherever possible (captain: parallel development is key), each with evidence-backed acceptance criteria.
7. Credit/cost budget for the generation program against ~24k Tripo credits, with the web fallback strategy.
8. Open questions / risks and a Rejected-alternatives table.

Write the full plan to the report path in the Definition of done.

# Herdr lifecycle declaration - NOT ENABLED
**HARD SAFETY GATE:** this scaffold cannot inspect the task text that replaces `{TASK}` later.
If the task will start, stop, delete, restart, profile, or otherwise drive Herdr lifecycle behavior, stop and regenerate the brief with `--herdr-lab` before dispatch.
Do not add Herdr lifecycle commands to this unguarded brief by hand.

# Setup
You are in a disposable git worktree of k-zero, at a detached HEAD on a clean default branch.
This is a SCOUT task: the deliverable is a written report, not a PR.
The worktree is your laboratory - install, run, edit, and make scratch commits freely; all of it is discarded at teardown.
The report is the only thing that survives, so anything worth keeping must be in it.

# Rules
1. Never push to any remote and never open a PR.
2. Stay inside this worktree; the only files you may write outside it are the report and the status file below.
3. Use gh-axi for GitHub operations and chrome-devtools-axi for browser operations.
4. Report status by appending one line:
   `echo "{state}: {one short line}" >> '/Users/leebarry/firstmate/state/kz-transform-c2.status'`
   States: working, needs-decision, blocked, paused, done, failed.
   Each append wakes firstmate, so report sparingly: only phase changes a supervisor
   would act on and the needs-decision/blocked/paused/done/failed states. No step-by-step
   FYI progress lines; firstmate reads your pane for that.
   Use `paused: {why}` - distinct from `blocked:` - ONLY when you are deliberately idling on a
   known external wait you expect to clear on its own (an upstream release, a rate-limit reset):
   firstmate then leaves your idle pane alone and rechecks it on a long cadence instead of
   treating it as a possible wedge. Use `blocked:` when you are stuck and need help.
5. If you hit the same obstacle twice, append `blocked: {why}` and stop; firstmate will help.
6. If a decision belongs to a human (product choices, destructive actions),
   append `needs-decision: {summary of options}` and stop. Firstmate will reply with the decision.
   When firstmate replies or a blocker clears and you resume, append `resolved: {how it was decided or unblocked}` (add the same `[key=<slug>]` if you opened it with one) so the decision or blocker is durably closed and does not keep resurfacing.
7. Never stop, restart, or update the shared `no-mistakes` daemon - it is one instance serving
   every lane/home, so restarting it kills other lanes' in-flight pipeline runs. On ANY no-mistakes
   daemon error, append `blocked: {the daemon error}` and stop; only firstmate manages the daemon.

# Definition of done
Write your findings to `/Users/leebarry/firstmate/data/kz-transform-c2/report.md`.
The report must stand alone: what you did, what you found, the evidence (commands run, output, file:line references), and what you recommend.
When the report is complete, append `done: {one-line conclusion}` to the status file and stop.
If your findings reveal work that should ship (e.g. you reproduced a bug and the fix is clear), say so in the report; firstmate may promote this task in place, and you would then receive mode-specific ship instructions as a follow-up message.
