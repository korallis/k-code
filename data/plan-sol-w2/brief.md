You are a crewmate: an autonomous worker agent managed by firstmate. Work on your own; do not wait for a human.

# Task
Produce a deep, detailed implementation plan for evolving k-zero from its current Phase 0 scaffold into a fully playable, smooth, AAA-quality F-Zero-style anti-gravity combat racer with cyberpunk styling. This is a PLANNING task: your deliverable is the plan document, not code.

## Current state (read the code first)
k-zero is a Vite + React 19 + TypeScript + react-three-fiber project with Rapier physics and SpacetimeDB in the stack. Phase 0: a 3D scene with a CC0 spaceship, dark ground, night HDRI, orbit controls, and an asset fetch/optimize pipeline. Known live bugs (a separate fix is already in flight - plan around it, do not re-plan it): track not properly visible, inverted left/right steering, turn rate far too fast and unsmooth.

## Product vision to plan for
- Look and feel: AAA-quality F-Zero clone - blistering sense of speed, smooth 60fps, readable track at speed, polished cyberpunk aesthetic (neon, holograms, night city skylines, synthwave palette).
- Core racing: anti-gravity ships on closed-circuit tracks, lap racing against AI opponents and (via SpacetimeDB) other players.
- Combat: players can destroy other players/AI; destroyed racers respawn after exactly 1 second at the location where they were killed.
- Pickups collectable around the track: varied weapons, plus upgrades - boost, shields, countermeasures (to evade/spoof incoming weapons), and similar. Design a concrete roster with rarity/placement logic.
- Assets: free/CC0 sources first (the existing pipeline pulls Quaternius/Poly Haven CC0 assets); where nothing suitable exists free, image assets can be generated with Grok's /imagine and 3D/audio via the installed threejs-3d-generator / threejs-image-generator / threejs-audio-generator skill pipelines. Plan the concrete asset list and which sourcing route each item takes.

## Research requirements (mandatory)
You have the Exa MCP server (web search) and Ref MCP server (technical documentation search) available - use BOTH, and cite what you used where:
- Exa: F-Zero GX / Wipeout handling and track-design analyses, anti-gravity racer physics writeups, arcade racer AI (rubber-banding), combat-racer weapon balance, cyberpunk visual language references.
- Ref: react-three-fiber performance patterns, @react-three/rapier APIs (kinematic vs dynamic bodies, raycast vehicle patterns), three.js curve/spline track geometry (TubeGeometry, ExtrudeGeometry along CatmullRomCurve3, frenet frames), SpacetimeDB module + client sync model, postprocessing (bloom, motion blur) budgets.
The user-level threejs-* skills (game director, gameplay systems, AAA graphics builder, UI designer, QA/release) contain relevant references and checklists - consult them where useful.

## The plan must cover, in depth
1. Architecture: game-state model, ECS-or-not decision, R3F scene organization, physics loop vs render loop, deterministic simulation considerations for netcode, module boundaries.
2. Track system: spline-based track authoring (closed circuits with banking, elevation, width variation), track surface rendering readable at speed, boundaries/walls, checkpoints/lap logic, minimap, and a concrete plan for at least 2 launch tracks.
3. Vehicle physics and game feel: hover suspension (raycast spring/damper), thrust/drag model, steering with smoothing and counter-steer, drift/air control, boost mechanics, collision response, camera work (FOV kick, shake, chase-cam lag) - with concrete tunable parameters and target values.
4. Combat and pickups: weapon roster (varied - e.g. projectile, homing, area, trap), pickup spawn/placement system, boost/shield/countermeasure design, damage/energy model (consider F-Zero-style shared energy-for-boost), destruction + 1-second respawn-in-place flow, balance rationale.
5. AI racers: racing line following, difficulty tiers, rubber-banding, combat item usage.
6. Multiplayer via SpacetimeDB: authority model, what state lives server-side, client prediction/reconciliation for a physics racer, respawn arbitration, lobby/matchmaking scope for v1 (be realistic about scope; propose a staged approach - e.g. local + AI first, multiplayer phase after).
7. Cyberpunk art direction: palette, lighting, post-processing stack and its frame budget, track environment set-dressing, ship livery, UI/HUD style (speed readout, energy bar, item slot, positions, lap timer).
8. Audio: engine, weapons, impacts, UI, music direction; sourcing route per category.
9. Performance budgets: draw calls, tris, texture memory, target devices; LOD/instancing strategy.
10. QA and verification: deterministic test hooks, Playwright smoke tests, bot playtests, visual regression - leaning on the installed threejs-qa-release patterns.
11. Phased delivery roadmap: ordered phases sized as individual PR-able work items, each with acceptance criteria, dependencies marked, and the critical path called out. Phase 1 should reach "smooth, fun single-track time-trial with great feel" fast, then combat, then AI, then multiplayer, then polish.

## Deliverable
Write the full plan to the report path given below in this brief's Deliverable section (data/<id>/report.md). Structure it with a summary at top, then the numbered sections above, then the roadmap. Cite Exa/Ref findings inline where they informed a decision. Be opinionated: pick one approach per decision and justify it; list rejected alternatives briefly.

Note: a second, independent planner is drafting the same plan in parallel. After both drafts land, you will each receive the other's draft for critique, and a converged plan will be synthesized - so make your reasoning explicit enough to be critiqued. When your draft is complete, report done per the status protocol below and then wait; the cross-review instructions will arrive as a follow-up message.


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
   `echo "{state}: {one short line}" >> '/Users/leebarry/firstmate/state/plan-sol-w2.status'`
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
Write your findings to `/Users/leebarry/firstmate/data/plan-sol-w2/report.md`.
The report must stand alone: what you did, what you found, the evidence (commands run, output, file:line references), and what you recommend.
When the report is complete, append `done: {one-line conclusion}` to the status file and stop.
If your findings reveal work that should ship (e.g. you reproduced a bug and the fix is clear), say so in the report; firstmate may promote this task in place, and you would then receive mode-specific ship instructions as a follow-up message.
