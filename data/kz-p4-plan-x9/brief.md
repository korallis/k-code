You are a crewmate: an autonomous worker agent managed by firstmate. Work on your own; do not wait for a human.

# Task
Draft an implementation plan for k-zero P4: multiplayer v1 on SpacetimeDB Cloud. This is a PLANNING scout - read the codebase deeply, produce a plan document, write NO implementation code.

You are one of TWO independent planners drafting in parallel (the other uses a different model). After both drafts land, firstmate will relay the other draft to you for cross-review, and yours to them. Your report will be critiqued line-by-line, so make every claim grounded in the actual code.

Hard constraints (captain-set, non-negotiable):
- Hosting is SpacetimeDB Cloud - the captain has an active subscription. NEVER plan self-hosting.
- Carried-forward contract from P1.3: the track compiler exports GAMEPLAY_HASH but nothing enforces it yet. P4 MUST add the hash handshake - match row stores {compilerVersion, gameplayHash}; server rejects clients whose artifact hash mismatches; client surfaces a clean "incompatible version" state.

Ground your plan in what's actually landed: deterministic sim + input ring buffer, track artifact compiler, racing AI core + AI item use, full weapon/utility roster (Pulse/Arc/Mine/Seeker/Rail/EMP-Quake + Aegis/countermeasures/Overdrive/Nanite), balance instrumentation, 8 selectable ships, two tracks (Neon + Black Rain Foundry). Read src/ and any existing SpacetimeDB scaffolding before writing a word.

The plan must cover, with concrete module/file-level detail:
1. SpacetimeDB schema (tables, reducers) - matches, players, inputs, state sync; the GAMEPLAY_HASH handshake above.
2. Netcode model for a high-speed racer: evaluate authoritative-server vs deterministic lockstep vs rollback/prediction against the existing deterministic sim + input ring buffer; recommend ONE with rationale and rejected alternatives.
3. Matchmaking/rooms/lobby flow, ship-select integration (8 ships), and race lifecycle (countdown, laps, finish, disconnect/rejoin).
4. Reconciliation of combat/weapons under latency (hit registration, item pickups, telegraphs/counterplay windows).
5. Anti-cheat basics proportionate to a browser game.
6. Migration plan from current single-player runtime (what changes in the game loop, what stays), schema-freeze checkpoint per the P3 exit gate (both AI tracks x 8 bots pass balance/fairness suites first).
7. Testing strategy: deterministic replay tests, simulated-latency harness, bot-vs-bot network soaks.
8. Phased milestones sized for single-PR increments, each with acceptance criteria (piloted QA where applicable).

Write the full plan to the report path in the Definition of done. Include an explicit "Open questions / risks" section and a "Rejected alternatives" table.

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
   `echo "{state}: {one short line}" >> '/Users/leebarry/firstmate/state/kz-p4-plan-x9.status'`
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
Write your findings to `/Users/leebarry/firstmate/data/kz-p4-plan-x9/report.md`.
The report must stand alone: what you did, what you found, the evidence (commands run, output, file:line references), and what you recommend.
When the report is complete, append `done: {one-line conclusion}` to the status file and stop.
If your findings reveal work that should ship (e.g. you reproduced a bug and the fix is clear), say so in the report; firstmate may promote this task in place, and you would then receive mode-specific ship instructions as a follow-up message.
