# K-ZERO: Implementation Plan — Phase 0 Scaffold → AAA-Quality Anti-Gravity Combat Racer

**Draft:** plan-fable-r7 (independent draft; a parallel draft exists and cross-review follows)
**Date:** 2026-07-13
**Repo state read:** detached HEAD at `f61aa75` (main), plus in-flight fix branch `fm/fix-track-b4` (`5f8b267 Fix track ribbon visibility and invert-safe steering feel`)

---

## Executive summary

K-zero is much further along than its README's "Phase 0" describes. The worktree already contains: a spline-based banked track builder with walls, checkpoints, boost pads and a start grid (`src/game/track/buildTrack.ts`); a 4-ray hover-suspension craft with grip/steer/boost physics on Rapier (`src/game/craft/PlayerCraft.tsx`); a local race loop with laps, splits and respawn (`src/game/race/`); a HUD; and working SpacetimeDB multiplayer (lobby, ready-up, server-validated transforms at 15 Hz, server-authoritative checkpoints/laps, ghost interpolation) with a TypeScript server module (`module/src/index.ts`). The known handling/visibility bugs are already being fixed on `fm/fix-track-b4`, which also introduces vitest and a pure `steerMapping.ts` — this plan builds on that branch's conventions (pure, unit-tested sim helpers; torque×dt steering).

The plan's core bets, justified in detail below:

1. **No ECS.** Extract a plain-TypeScript, fixed-tick simulation core (`src/sim/`) that owns racers, combat, items and AI, stepped once per Rapier tick via `useBeforePhysicsStep`; R3F components become views. ~10 racers + ~30 short-lived entities do not justify ECS indirection, and the pure-module pattern is already the codebase's idiom and is unit-testable (the fix branch proves it).
2. **No lockstep determinism.** Rapier-JS is deterministic only same-build/same-inputs, and JS `Math.*` transcendentals vary across engines; chasing determinism for netcode is a trap. Keep the existing model — client-authoritative movement with server plausibility validation, server-authoritative race progression — and extend it with **server-authoritative combat resolved in track-space coordinates** inside SpacetimeDB scheduled reducers (no physics engine needed server-side).
3. **Energy is the one resource** (F-Zero GX model): boost and survival draw from the same meter; kills refund energy; recharge strips create route decisions. This single mechanic supplies risk/reward depth, combat stakes, and the 1-second respawn-in-place loop the brief specifies.
4. **Feel first, then combat, then AI, then multiplayer combat, then content/polish** — with a bot-driven QA harness (the AI racing-line follower doubles as the CI playtest driver) added in Phase 1, not at the end.
5. **Readability at speed is an art-direction constraint, not a post-process**: edge light ribbons, repeated vertical scenery for optic flow, chevroned corners, fog-anchored horizon — all cheap, all instanced.

Sections 1–11 follow the brief's numbering. Roadmap with PR-sized work items, dependencies and the critical path is at the end. Research citations (Exa web research, Context7/official docs, and the installed threejs-* skill checklists) are inline where they informed a decision.

> **Note on the "Ref MCP" requirement:** this session's tooling exposes Context7 (technical-documentation search MCP) rather than a `ref_search_documentation` tool; Context7 plus fetches of official docs (rapier.rs, pmndrs docs, spacetimedb.com, threejs.org) via Exa filled the same role. Citations below name the doc source per finding. SpacetimeDB TypeScript SDK facts additionally come from the repo's own `module/CLAUDE.md` SDK reference.

---

**How this plan was produced (method & evidence):** (1) full read of the k-zero worktree at `f61aa75` plus the in-flight fix branch diff (`git diff main fm/fix-track-b4`) — all file:line claims below come from that read; (2) Exa web research across F-Zero GX/Wipeout mechanics (RAM-verified community docs), hover-physics implementations, arcade-AI/rubber-banding literature (Game AI Pro ch. 39/42), item-balance data (MK8 probability tables), sense-of-speed studies, and cyberpunk visual-language references; (3) technical-documentation research via Context7 + official-doc fetches (react-three-rapier, rapier.rs, three.js sources, r3f/drei, postprocessing, spacetimedb.com) — see the note above on the Ref-server substitution; (4) digest of the nine installed `threejs-*` skills' checklists, budgets, and generator pipelines. Full source-to-section mapping is in Appendix A.

---
## 0. Current-state inventory (what the plan builds on)

Read directly from the worktree; file:line references are to main (`f61aa75`).

**Rendering & scene** — `src/game/Scene.tsx`: R3F Canvas, fixed `<Physics timeStep={1/60} interpolate>`, `NeonOrbitalScene` (default) with fog, Stars, city equirect env, Bloom (mipmapBlur, intensity 0.75, threshold 0.85); `?scene=arena` flat test arena. Camera far plane 1100. `dpr={[1,2]}`, shadows on (1024 map).

**Track** — `src/game/track/buildTrack.ts`: closed `CatmullRomCurve3` through `TrackDef.points` (`pos`, optional `width`, `bank` degrees); arc-length parameterized sampling (512 segments); frames from `tangent × worldUp` (planar assumption), bank applied by rotating right/up around tangent; ribbon BufferGeometry with per-sample normals/UVs; wall meshes plus **cuboid-chain wall colliders** (256 segments/side) to avoid trimesh seam-catch (`buildTrack.ts:325-349`); 8 checkpoint sensor transforms, boost-pad transforms, 8 grid slots. `Track.tsx` renders PBR asphalt ribbon (ambientCG Asphalt006), metal-plate walls, emissive cyan edge stripes + magenta wall-top stripes (merged box geometry), pulsing boost pads, start gate; physics = one fixed body (ribbon trimesh + wall cuboids), sensors on a second body. `tracks/neonOrbital.ts`: ~1.5–1.8 km, 14 points, banked sweeps (22–26°), climb, 30°-banked hairpin (width 10), downhill S, flyover, carousel; 3 boost pads; `Scenery.tsx`: pylons every 40 m, ≤150 Kenney barrier instances, inward-facing skyline ring (Grok-generated `skyline-a/b.jpg`), 8 neon billboards (generated), Quaternius planets.

**Craft** — `src/game/craft/PlayerCraft.tsx`: dynamic RigidBody + 2×0.6×3 m cuboid collider; hull collides **only with walls**; 4 corner rays (down local −Y, range `rideHeight×2`) hit **only the surface** group (`physicsGroups.ts`) — suspension owns the ground exclusively, spring `k=320` compression + damper `c=30` inner band, damper-only outer band ×0.5; slerped surface alignment preserving yaw (`alignStrength 4`); thrust 140 projected on ground plane; lateral-grip model that kills sideways velocity and **redirects 85% of it into forward** (`gripRedirect`), drift halves grip (0.35); yaw torque steering with speed scaling and a hard yaw-rate cap; horizontal speed clamp 45 m/s; boost impulse 18 with 1 s cooldown; spawn grace until ground exists. Chase camera: exp-lerp (rate 10), distance clamp 5.5–10 m, min height, FOV 50→65 by speed fraction. `useInput.ts`: WASD/arrows + Shift drift + Space boost, steer attack/release shaping, thrust ramp; merged with `window.__KZERO_DEBUG.setInput` override (E2E-ready). `tuning.ts` on the fix branch: `steerTorque 28` (continuous torque × dt), `steerAttack 3.2`, `steerRelease 5.5`, `maxYawRate 1.05 rad/s`, `angularDamping 5.5`, plus documented feel targets; `steerMapping.ts` (+ vitest test) fixes the left/right inversion with an explicit sign convention.

**Race loop** — `src/game/race/raceState.ts`: framework-free store (subscribe/snapshot), idle→countdown(3 s)→racing→finished, 3 laps × 8 in-order gates, lap/best/splits; `RaceController.tsx`: auto-start when craft ready, KeyR/fall (y<−25) respawn to last gate with 1 s input lock. `hud/Hud.tsx`: lap, total/last/best, next gate, km/h (15 Hz poll of debug bridge), countdown + GO flash, results panel.

**Netcode** — `module/src/index.ts` (SpacetimeDB TS module): tables `player`, `race` (single row, status lobby/countdown/racing/finished), `participant` (grid slot, lap, next_checkpoint, finish/best ms), `transform` (pos/rot/vel + **authority identity column**), scheduled reducers `start_race`, `finish_timeout` (300 s); reducers `join_lobby` (≤8, grid-slot assignment), `set_ready` (all-ready ≥2 → 3 s countdown), `publish_transform` (authority check; **rejects speed >80 m/s and >30 m jumps without respawn flag**), `cross_checkpoint` (in-order gate validation, ≥3 s split floor, lap/best/finish computation, all-finished → finished), `reset_lobby`, disconnect cleanup. Client: `net/spacetime.ts` singleton (token in localStorage, subscribes to all 4 tables), `transformSync.ts` publishes own body at **15 Hz** with respawn re-flag self-heal, ingests remote transforms into 10-deep buffers, **interpolates ghosts at now−120 ms with Hermite (position+velocity)**; grid teleport on countdown entry; `GhostCraft.tsx` renders remote ships with per-player emissive tint.

**Pipeline & tooling** — `scripts/fetch-assets.mjs` (Quaternius Ultimate Space Kit, Polygonal Mind `pm-aero-system`/`pm-tomb-chaser-2` (cyber ads, columns) /`pm-transit`, Poly Haven HDRIs, ambientCG Asphalt/Road/MetalPlates, Kenney racing props) → `optimize-assets.mjs` (meshopt via gltf-transform, 177 models, 85 MB in `public/assets/opt/`). Vite manual chunks for three/r3f/rapier/stdb. Leva debug panel (dev-only). `window.__KZERO_DEBUG` bridge: `setInput/getState/teleport/getNet/getRace/raceStart/raceReset/respawn` — a deliberate test/automation surface.

**Gaps vs. the product vision** (what this plan adds): energy/damage/combat, pickups/weapons, AI racers, positions/standings, minimap, respawn-in-place (current respawn is at-last-gate), sense-of-speed package (speed is capped at 45 m/s ≈ 162 km/h and reads slow), second track, audio (none at all today), server-side combat/respawn arbitration, ship variety, title/menu flow, settings, QA automation beyond the one steering unit test, and performance hardening (KTX2, LOD, instancing coverage).
## 1. Architecture

### 1.1 Game-state model: three tiers, one tick

**Decision: no ECS.** Peak entity count is ~8 racers + ~30 projectiles/mines + ~40 pod states + FX. ECS (miniplex/bitECS) pays off at thousands of homogeneous entities or when composition churn is high; here it would add indirection to a codebase whose idiom — framework-free TypeScript modules with subscribe/snapshot stores (`raceState.ts`, `spacetime.ts`) and R3F components as views — already works and is already unit-testable (the fix branch's `steerMapping.ts` + vitest proves the pattern). The gameplay-systems skill recommends exactly this shape: `core / game / entities / systems` plain modules with a fixed update order, "don't invent abstractions before mechanics need them" (`~/.claude/skills/threejs-gameplay-systems/references/gameplay-workflows.md`). Rejected: miniplex (nice API, unneeded layer), class-hierarchy OO entities (poor testability), Redux-style single store for sim data (GC pressure at 60 Hz).

Three state tiers with different owners and rates:

1. **Sim state (60 Hz, mutable, allocation-free)** — `src/sim/`: one `SimWorld` object holding `racers[]` (craft dynamics handle + energy + item + progress + status), `projectiles[]`, `mines[]`, `podTimers[]`, `raceClock`. Stepped exactly once per Rapier tick. Plain arrays and preallocated scratch (the codebase already does the scratch-vector discipline in `PlayerCraft.tsx:37-55`).
2. **UI state (event rate)** — existing store pattern (`subscribe/snapshot` + `useSyncExternalStore`): race phase, lap/splits, standings, HUD data at 10–15 Hz coalesced snapshots, kill feed. Keep the hand-rolled stores; **do not add zustand** — two hand-rolled stores already exist, they're 60 lines each, and consistency beats a marginal API win. (Rejected: zustand — fine library, but it would make three state idioms in one repo.)
3. **Net state (15 Hz in / event out)** — the existing `net/` layer unchanged in shape: SpacetimeDB row cache → snapshot; sim reads remote transforms from interpolation buffers, writes own transform + events via reducers.

Events between tiers: a preallocated ring buffer `simEvents` (`{type, tick, a, b, x,y,z}`) written by sim, drained each render frame by FX/audio/HUD bridges. No allocations, no React in the hot path (r3f pitfalls doc: never route frame data through setState — Ref: r3f `pitfalls.mdx`).

### 1.2 Physics loop vs render loop

Keep `<Physics timeStep={1/60} interpolate>`; it is the documented canonical racer loop: fixed step + interpolation, forces applied in `useBeforePhysicsStep` which runs once **per physics step**, not per frame (Ref: react-three-rapier README — `timeStep="vary"` "may cause instability… prevents the physics simulation from being fully deterministic"). Today each craft registers its own `useBeforePhysicsStep`; replace with **one** `SimRoot` component that owns the single callback and steps everything in fixed order:

```
inputs (player smoothing, AI controllers, remote buffer reads)
→ craft forces (all racers, same computeCraftForces)
→ weapons/projectiles (kinematic sweeps)
→ damage/energy/destruction/respawn timers
→ progress/standings update
→ simEvents emit
```

matching the skill's `input → physics → gameplay → camera → UI bridge` contract (gameplay-workflows.md). Render-rate work (`useFrame`): camera, FOV/shake decay, trails, HUD polls, ghost interpolation. Rationale for one callback: deterministic system order (multiple hooks have registration-order semantics), one place to pause/step for tests (`useRapier().step(1/60)` with `<Physics paused>` is the documented manual-stepping API — Ref: react-three-rapier README "Manual stepping").

**Catch-up rule:** rapier's internal accumulator already handles render-rate ≠ sim-rate; clamp is built in, but our sim must tolerate 2–3 steps per frame after a hitch (no per-step DOM/React work — already true).

### 1.3 Determinism policy (the netcode-shaping decision)

Facts (Ref: rapier.rs "Determinism" page; r3f-rapier README): Rapier's WASM build is bit-deterministic across platforms **given** identical version, identical insertion order, identical inputs, fixed timestep — but JS `Math.sin/cos` (used across our sim and three.js quaternion math) are *not* cross-engine deterministic, and any float that flows from them into the world breaks the guarantee.

**Decision:** treat the simulation as **locally replayable, not cross-client deterministic**. Concretely:

- All sim randomness through one seeded PRNG (`src/sim/rng.ts`, mulberry32); all timers in integer ticks; input captured as a per-tick log. This gives **same-machine replay** (bug repro, ghost laps, regression tests — §10) without pretending to lockstep.
- Netcode never assumes two clients compute the same result (§6): movement is client-authoritative + server-validated; combat is server-resolved in track-space.
- Rejected: deterministic lockstep (GGPO-style) — would require fixed-point or WASM-only math for *all* gameplay code, plus rollback; Rapier `world.takeSnapshot()/restoreSnapshot()` is checkpoint-grade (full-world serialize into a *new* World object, awkward under react-three-rapier's managed world), not per-frame rollback-grade (Ref: rapier.rs serialization docs).

### 1.4 Module boundaries

```
src/
  sim/            # pure TS, zero three/react imports where possible; vitest lives here
    craftSim.ts   rng.ts   energy.ts   progress.ts   respawn.ts   standings.ts
    weapons/ (pulse.ts missile.ts mine.ts rail.ts quake.ts leech.ts emp.ts …)
    items.ts      # roster + distribution tables (§4.3)
    ai/ (racingLine.ts driver.ts itemBrain.ts difficulty.ts)
  game/           # R3F: SimRoot, CraftView, ProjectileView, TrackView, FxLayer, CameraRig
  content/        # tracks/*.ts, ships.ts, palette.ts (data only)
  net/            # spacetime.ts, transformSync.ts, combatSync.ts, raceBridge.ts, bindings/
  hud/            # React DOM
  audio/          # engine.ts, sfx.ts, mixer.ts
  fx/             # trails, sparks, explosion pools, speedlines
module/           # SpacetimeDB TS module (server truth)
tests/            # Playwright specs; sim unit tests co-located in src/sim
```

Dependency rule (enforceable by eslint-plugin-boundaries later, or convention now): `sim` imports nothing from `game/net/hud`; `game` renders from `sim` + stores; `net` bridges `sim` ↔ SpacetimeDB; `hud` reads stores only. `content` is data-only so tracks/ships stay diffable and hot-reloadable. The existing `debugBridge.ts` global-registry pattern stays as the seam between React-world and module-world but shrinks: most registrations become `SimWorld` fields.

### 1.5 Scene organization

One `<Canvas>`; scenes as components selected by a tiny app-state machine (`menu → lobby → race → results`), not URL params (keep `?scene=arena` as a dev door). Race scene composition: `SimRoot` (logic), `TrackView` + `Scenery` (static, all instanced), `CraftView ×N` (player + AI + remote, same component, driver injected), `FxLayer` (pooled particles/trails), `CameraRig` (owns the camera exclusively — today `PlayerCraft` mutates the default camera inline; extracting `CameraRig` is a Phase 1 refactor so shake/FOV/finish-cam compose). Suspense boundaries around GLTF/HDRI so physics never blocks on assets (pattern already in place at `Scene.tsx:47`, `PlayerCraft.tsx:501-505` — keep).

---

## 2. Track system

### 2.1 Authoring model: keep control points, extend the schema

`TrackDef` (control points with `pos/width/bank` + derived arc-length sampling) is the right authoring granularity — it survived building a real 1.6 km circuit in 14 points. Extend to:

```ts
type TrackPoint = { pos: [x,y,z]; width?: number; bank?: number };  // as today
type TrackDef = {
  …existing…
  rechargeStrips: { t: number; length: number }[];      // §3.4 energy
  itemPods: { t: number; lateral: -1|0|1 }[];           // §4.3 (lateral thirds)
  hazards?: { t: number; kind: "slick"|"magnet" }[];    // Phase 6 candidates, schema now
  sections?: { from: number; to: number; name: string }[]; // named for HUD/minimap/telemetry
  palette: TrackPalette;                                 // §7 per-track colorway
  music?: string;
};
```

**Frames:** keep the current `tangent × worldUp` reference frame + explicit bank rotation for v1 (it's what makes authored banking deterministic and it cannot twist), and **do not** switch to `computeFrenetFrames`: three's implementation parallel-transports from an *arbitrary* initial normal and then smears the closed-loop mismatch as a distributed twist ("twist a little…" in `Curve.js` source) — you cannot author banking with it (Ref: three.js `Curve.js` source via docs research; TubeGeometry inherits the same frames). The world-up cross fails only when the tangent goes vertical; v1 tracks stay under ~35° pitch. **Phase 6 (loops/corkscrews): upgrade `buildTrack` to RMF parallel transport** — carry the previous sample's `right` through `cross` products instead of re-deriving from world-up (the code already keeps `prevRight` for the vertical-epsilon case at `buildTrack.ts:100-114`, so this is a contained change), add per-point `roll` (bank becomes roll relative to transported frame), and enable §3.1 track-relative gravity. CatmullRom stays `centripetal` (default; avoids cusps/self-intersections between uneven control points — Ref: three.js CatmullRomCurve3 docs).

**Arc-length correctness:** raise `curve.arcLengthDivisions` to ≥ 4× control-point count × 50 before `getLengths` (default cache is 200 divisions — coarse for a 2 km loop; Ref: three.js Curve docs/source: `getPointAt` binary-searches the cached table). Precompute everything at build; runtime never calls `getPointAt` (per-tick queries hit the 512-sample tables — §2.5).

### 2.2 Geometry & readability at speed

The ribbon + wall extrusion + cuboid-chain wall colliders stand (trimesh walls seam-catch; the cuboid chain at `buildTrack.ts:325-349` is the correct fix and stays). Additions, all driven by the same samples:

- **Surface shader, not more geometry.** One `ShaderMaterial`-extended standard material on the ribbon: UV.x is arc-length (already true) → animate subtle forward-flowing energy grid lines; UV.y edges → built-in edge glow AA'd in shader (replaces some merged-box stripe geometry); distance-based fade of fine detail so the surface reads coarse at speed. Hargreaves' MotoGP lesson: coarse, *varied* surface detail near the racing line is the cheapest speed multiplier — add baked grime/skid decal variation via a second UV-offset noise channel (Exa: shawnhargreaves.com "vrrroom whoosh").
- **Corner language:** chevron decal strips (instanced quads from samples) starting 80 m before any sample where |curvature| exceeds a threshold, density ∝ severity — detail density *is* the braking signage (Exa: Hargreaves; gameplay-systems level-design checklist: "readable apexes, braking cues").
- **Hue separation contract (hard rule):** ribbon surface = dark desaturated slate; edge light = cyan; walls = darker steel with magenta top stripe; skyline = violet haze. Redout's documented failure is track/railing/skybox sharing hues until they blur into one at speed (Exa: pietriots.com Redout color analysis). This is a lintable palette rule in `content/palette.ts`, not a vibe.
- **Optic-flow scenery rhythm:** pylons every 40 m (exists) + catenary cables between them + overhead gantry every ~150 m + light-pulse shader running along wall stripes in the travel direction. Repeated near-track verticals are the parallax metronome (Exa: Hargreaves; Distance/Tron edge-light language).
- **Horizon anchors:** keep skyline ring + planets; add 2–3 mega-towers with slow-blinking beacons placed so at least one is visible from every track section (orientation through twists — Exa: cyberpunk track-design digest).

### 2.3 Boundaries & hazards

Walls everywhere in v1 (open edges + rail-less drops are a Phase 6 hazard vocabulary, gated on §3.1 gravity work). Wall top stripe doubles as the "you are near the wall" warning by brightening within 2.5 m lateral (shader uniform per-side). Kill plane stays y < −25 → treated as destruction (§4.1) so all recovery flows through one respawn path.

### 2.4 Checkpoints, laps, progress

Gates stay the **authority** (8 sensors, in-order, server-validated in MP — anti-cheat by construction, `module/src/index.ts:209-251`). Add continuous **progress** for standings/AI/rubber-banding/minimap: `progress.ts` maintains per-racer `s` (arc-length fraction) by local search around last `s` over the 512-sample table (compare squared distance to neighboring samples; O(1) per tick per racer, robust because crafts move ≤ 1.5 samples/tick at max speed). Total ordering = `lap*L + s·L − penalty(wrongGate)`. Standings recompute at 10 Hz into the UI store. Rejected: closest-point-on-curve via `getPointAt` iteration per tick (needless trig) and Rapier sensors for progress (already have gates; progress needs continuity, not events).

### 2.5 Minimap

Canvas-2D overlay (not a second WebGL render pass): draw the sampled center-line polyline once into an offscreen canvas at load (XZ projection, auto-fit), per-frame blit + racer dots from `progress`-interpolated positions, self always centered-rotated (map rotates, dot fixed — racing-game convention for track-relative reading). Elevation ignored (v1 tracks are near-planar; the flyover crossing draws as an overpass tick). Cost: ~0 GPU. Rejected: render-to-texture 3D minimap (a full extra render pass for cosmetics violates the §9 budget).

### 2.6 Launch tracks (2)

**Track 1 — Neon Orbital (exists, upgrade pass):** widen hairpin 10→11.5 m (combat needs dodge room; §3.2 sideshift is 7 m/s — a 10 m lane leaves no dodge margin), add recharge strips on the start straight (t≈0.02–0.06) and before the hairpin (t≈0.40–0.44) so boost economy has two decision points/lap, 9 item-pod rows per §4.3, move one boost pad onto the flyover (reward the high line), chevron/gantry pass per §2.2. Character: "first track" — one of everything, nothing twice.

**Track 2 — Vector Sunset (new):** synthwave dusk palette (§7: horizon gradient `#FF2DAA→#7C4DFF`, sun-grid billboard anchor), ~2.3 km, 16–18 control points: 420 m back straight (slipstream + Rail Lance duels; longest sightline in the game), heavy 35° carousel (tests sustained banking + §3.1 gravity), double-apex right, chicane with item pods on the inside (risk/reward: pods vs line), short tunnel (audio reverb moment + bloom contrast exit), crest jump into a downhill left (§3.2 pitch-control showcase), 2 recharge strips, 12 pod rows, 4 boost pads. Elevation ±14 m, min width 11, max 18 (width variation is the "route rhythm" the level-design checklist demands — skills digest: game-design-level-design.md; every skill-test on its list maps to a section: clean line = carousel, boost timing = crest, drift angle = double-apex, traffic threading = chicane pods, shortcut risk = high flyover line on T1).

Both tracks must pass the **greybox gate** before art: bot (§5) completes laps, lap time 55–75 s, no section where the Ace bot's line touches a wall (skills digest: "greybox first to prove scale/route/timing").
## 3. Vehicle physics and game feel

### 3.1 Keep the current hover model; it matches the proven pattern

The existing craft (4 corner rays, per-corner spring `F = k·compression − c·v_normal`, damper-only outer band, alignment slerp, lateral-grip-with-redirect) is exactly the architecture independent hover-racer writeups converge on: per-corner spring/damper beats both single-ray PID (stable but can't give roll/pitch) and multi-ray PID (oscillates); disabling spring push beyond ride height so thrusters "don't fight during falls" is already implemented as the damper-only outer band (Exa: mads.blog sci-fi racing parts 2–3; Unity hover-racer discussions). **Decision: no rewrite.** Rejected: Rapier's `DynamicRayCastVehicleController` (rapier.rs docs) — it models wheeled suspension with friction at contact patches; our grip model is deliberately not tire-like, and we'd lose the tuned redirect behavior.

Two structural changes:

1. **Extract pure force math into `src/sim/craftSim.ts`.** `PlayerCraft.tsx`'s `useBeforePhysicsStep` body becomes: read body state → call `computeCraftForces(state, input, probes, tuning, dt)` → apply returned forces/impulses/velocity edits. The fix branch's `steerMapping.ts` + vitest establishes this idiom; extend it to the whole force model so feel changes get unit tests (e.g. "at 60 m/s, full steer yields yaw rate ≤ maxYawRate within 0.4 s"; "lateral speed after 1 s of grip < 5% of entry"). Every racer (player, AI, and later host-simulated ghosts) runs this same function — one craft sim, N drivers.
2. **Track-relative gravity, staged.** Today: world gravity + `gravityExtra` down when airborne. For banked bowls and (Phase 6) loops, adopt the Unity hover-racer gravity split validated by shipped tutorials: when grounded, zero world gravity (`setGravityScale(0)`) and apply `−surfaceNormal × hoverGravity`; when airborne, restore world-down with stronger `fallGravity` (their reference ratio 20 grounded / 80 airborne; ours: 25/55 to start) (Exa: Unity Hover Racer pattern via discussions.unity.com; mads.blog). This is also the documented fix for "ship spins out when inverted": torque about *local* up, align via `cross(shipUp, surfaceNormal)` — our alignment slerp already does the equivalent. v1 tracks stay loop-free; this change ships when Track 2's half-pipe section lands so it's soak-tested before any full loop.

### 3.2 Tunable table (current → target, with rationale)

All in `CRAFT_TUNING` (post-fix-branch baseline). DT = 1/60 fixed (unchanged).

| Parameter | Now | Target v1 | Why |
|---|---|---|---|
| `maxSpeed` (m/s) | 45 | **58** base | 45 m/s reads slow even with FOV kick; 58 m/s ≈ 209 km/h real. Sense of speed comes from the §3.5 package, not raw m/s alone (Exa: Hargreaves MotoGP postmortem — they *slowed bikes down* while making it feel faster). |
| boost speed cap (m/s) | n/a (impulse only) | **76** while boosting | Boost must visibly break the ceiling. |
| pad boost | impulse 18, 1 s cooldown | **+14 m/s along tangent, cumulative, hard cap 88 m/s** | GX dash plates *add* to current speed rather than set it — stacking pads/boost is the skill expression (Exa: mutecity.org/wiki/Boost, speeddemosarchive GX page). |
| `thrust` | 140 | 165 (×1.35 while boosting) | Reach new top speed in ~6 s from standstill. |
| `linearDamping` | 0.55 | 0.55 powered; **0.30 when throttle released above 90% max** | GX "Momentum Throttle": coasting decays slower than powered over-speed — the cheapest emergent-depth rule in the genre (Exa: tasvideos GX resources, speeddemosarchive). Creates lift-and-coast lines. |
| `steerTorque` | 28 | 28, ×**1.5 counter-steer** (sign(steer) ≠ sign(yawVel)) | Snappy corrections without raising base twitchiness; echoes GX Quick Turn. |
| steering authority vs speed | flat | ×lerp(1.0 → 0.82) from 0 → max speed | High-speed stability; keeps `maxYawRate` cap from being the only guard. |
| `maxYawRate` (rad/s) | 1.05 | 1.05 base / **1.45 while drifting** | Drift must out-rotate grip steering or it has no purpose. |
| `driftGrip` | 0.35 | 0.35, + **mini-turbo**: drift held ≥1.1 s with lateral slip ≥6 m/s ⇒ +9 m/s impulse on release | Rewards committed drifts; readable (charge glow on engine). Rejected: GX snaking (turn-gains-speed) — it's an exploit that dominates high-level play and looks broken to everyone else. |
| airbrakes | none | **hold Q/E**: per-side drag 0.5 + extra yaw torque 9 toward that side | Wipeout's core cornering verb; one-side airbrake tightens the line, effect ramps over ~0.6 s (Exa: wipeout.wiki handling). |
| sideshift | none | **double-tap Q/E**: instant ±7 m/s lateral impulse, 0.9 s cooldown | Wipeout's dodge; this is the movement counter to §4 weapons. |
| pitch (airborne) | none | stick pitch torque, clamp ±0.5 rad relative to surface; nose-down shortens jumps, landing misaligned >25° ⇒ 6% speed loss + 4 energy | GX/Wipeout air discipline: level landings preserve speed (Exa: GX SDA page; wipeout.wiki pitch). |
| `alignStrength` | 4 | 5 grounded / 2 airborne | Faster surface tracking on banking; lazier in air so pitch control reads. |
| suspension | k=320, c=30 | unchanged; re-verify at 76 m/s over crests (raise `rayRangeMult` 2→2.5 if outer band drops contact) | Don't touch what's tuned; test at new speeds. |

Input additions: Q/E (airbrake/sideshift), Space stays boost (energy-gated, §3.4), Shift stays drift, item fire = left click / X key, absorb = hold item key. Gamepad mapping in Phase 5 (analog steer already supported by the smoothing model).

### 3.3 Collision response

- **Walls:** frictionless slide already merged (`1f33e2c`). Add: on contact with |velocity into wall| > 4 m/s, apply energy damage = `0.5 × impactSpeed`, capped 12 per contact event (adapted from GX's `0.01 × km/h × angle`, capped; Exa: fzerogx-docs energy.md), 250 ms damage-retrigger lockout, spark burst + scrape loop + trauma 0.25. Rationale: walls must cost something or the optimal line is wall-riding — but never stop the craft (Wipeout 2097's "scrape, don't halt" lesson; Exa: 2097 design retrospectives).
- **Craft vs craft:** restitution 0.4, equal mass; lateral shove is a legitimate weapon (GX side-attack). Post-respawn 2 s: no craft-craft collision (ghost) + no damage (invulnerable) to prevent spawn-kill loops.
- **CCD stays on** for crafts (already `ccd`); projectiles are sensors moving via kinematic sweep, not dynamic bodies (§4.5).

### 3.4 Boost = energy (the F-Zero economy)

Replace the binary 1 s cooldown boost with the GX shared meter — the single mechanic that makes the whole game cohere (risk/reward per corner, kill incentive, recharge routing):

- Energy 0–100. **Hold-boost drains 30/s** (GX: full bar ≈ 10 s of boost — ours matches at 100/30 ≈ 3.3 s... deliberately hotter; see below), grants thrust ×1.35 and cap 76 m/s. Engage floor: energy > 5.
- **Recharge strip** (new track element, §2): +65/s standing (GX refills full in 1.5 s at +66.7/s; Exa: fzerogx-docs energy.md), net +35/s while boosting on it.
- **Kill refund +25**, victim respawns with **50** (GX respawn convention: half bar; Exa: fzerogx-docs).
- Damage sources: weapons (§4), walls (§3.3), bad landings.
- Why drain 30/s not GX's 16.7: our laps are ~60–90 s and races 3 laps; a hotter drain makes boost a *decision* several times per lap rather than a lap-2 dump. Tune via §10 bot duels; expose in leva.

Boost feedback stack (from the threejs-gameplay-systems game-feel reference, numbers verbatim): FOV punch +6° decaying `exp(−dt/0.2)`, stretch 1.15 volume-preserved ~180 ms, whoosh SFX, light rumble 180 ms/0.3, engine pitch +25%; camera trauma 0.2. (`~/.claude/skills/threejs-gameplay-systems/references/game-feel.md`.)

### 3.5 Camera and sense-of-speed package

Research consensus: FOV is the highest-ROI speed cue (ArtsIT 2016 study), **motion blur measurably does not help** (Disney Split/Second study) and strong blur *reduces* perceived speed — so we spend zero budget on motion blur and everything on FOV + parallax + near-field detail (Exa: eudl.eu ArtsIT paper; Disney Research PDF; Hargreaves "vrrroom whoosh").

| Camera param | Now | Target |
|---|---|---|
| base FOV | 50 | 52 |
| speed FOV | +15 by speed fraction | +16 by speed², **+6 boost punch** (decay 200 ms), clamp 78 |
| height above craft | 3.0 | **3.0 → 2.2** as speed→max (whoosh ∝ 1/height — Hargreaves) |
| distance | 7 (clamp 5.5–10) | 7 → 8.6 at max; clamp unchanged |
| position lerp rate | 10 | 11, and rotation slerp 14 (split pos/rot lag: pos lags more in corners = drift readability) |
| look-at | craft +0.5 up | craft + **velocity·0.18 s lookahead**, +0.4 up — camera leads into corners |
| lateral offset | 0 | 0.35 m toward steer direction |
| shake | none | trauma system: shake = trauma², decay 1.4/s, max offset 0.55, max roll 0.1 rad, noise freq 32 Hz; events: wall scrape 0.25, weapon hit 0.4, explosion nearby 0.7, boost 0.2, landing 0.15 (skills digest: game-feel.md — verbatim recipe) |

Plus: screen-edge speed-line shader (radial streaks sparing center, opacity ramps >80% speed — cheap fullscreen quad, not a post pass), engine-trail ribbons on all crafts (light streaks read as speed at zero cost — Exa: gamedev.stackexchange illusion-of-speed thread), near-track detail density (§2.4/§7: pylons every 40 m already; add catenary cables, overhead gantries every ~150 m, decal grime on the ribbon — Hargreaves: coarse varied road texture + overhead clutter was their single biggest win, applied while *reducing* actual speed).

Display speed: HUD shows `m/s × 3.6 × 2.2` labeled "km/h" (≈460 at base top, ≈600 boosted). Genre-anchored fiction (F-Zero reads 900–1500; honest 209 km/h feels like a compact car). One constant, reversible. Rejected: honest km/h (reads slow); made-up units (players still convert).

---

## 4. Combat and pickups

### 4.1 Damage/energy model

One meter (§3.4). No separate HP. Wipeout HD's second-best idea is imported too: **absorb** — hold the item key 0.6 s to convert the held item into energy (per-item values below), so every pickup is a fire-vs-heal decision and trailing players can play defensively without being helpless (Exa: wipeout.wiki HD — absorb refunds scale with weapon rarity: Leech 10 … Plasma/Quake 40).

Destruction: energy ≤ 0 ⇒ `destroyed` state: explosion VFX/SFX, input locked, hull hidden, collider disabled; **respawn after exactly 1.0 s (60 sim ticks) at the death location** projected to the nearest track cross-section (same arc-length `s`, lateral clamped to ±(width/2 − 1.5 m), snapped to ride height +0.5 m, oriented to the track frame at `s`, velocity = 35% of pre-death forward). Death over void or outside the ribbon projects to `s` center-line — this also covers fall-outs, which become "destroyed" too (unifies the current respawn-at-gate path; gate respawn is removed). Post-respawn: 2 s invulnerable + craft-craft ghost, shield-flicker shader. The 1 s timer counts sim ticks, not wall clock, so replays/tests are exact (§10). Multiplayer arbitration in §6.4.

Balance rationale: kills reward +25 energy (≈ one boost decision) and cost the victim ~3–4 s (1 s dead + relaunch from 35% speed) plus half a meter — meaningful but not race-ending, which is the documented sweet spot for combat racers where racing stays primary (Exa: Wipeout Eliminator vs race modes; Smidelov GX multiplayer analysis: kill refunds feed the boost economy).

### 4.2 Weapon roster (7 weapons, 3 utility)

Varied by guidance/geometry/counterplay, per the brief. Damage in energy points (meter = 100). Names are working titles in the synthwave register.

| # | Item | Class | Behavior | Dmg | Counterplay | Absorb |
|---|---|---|---|---|---|---|
| 1 | **Pulse Burst** | projectile | 3-shot burst, 120 m/s, flat, 1.5° spread, range 180 m | 3×7 + hit slows target 8% for 1 s | sideshift; lateral offset | +12 |
| 2 | **Hunter Missile** | homing | 0.7 s lock (target ahead ≤45 m in 50° cone), 95 m/s, 4 rad/s turn, 6 s fuel | 22 + heavy shove | flare; hard sideshift behind wall lip; forces lock-tone counterplay | +18 |
| 3 | **Shock Mine** | trap | drops behind, arms 0.5 s, lives 30 s, max 3/player, proximity 2.2 m | 18 + yaw kick (spin) | visible neon glow; drive around; flare detonates in radius | +15 |
| 4 | **Rail Lance** | hitscan | 1.2 s charge with visible beam telegraph along your forward ray, then instant hit, range 300 m | 30 | telegraph gives ~1.2 s to dodge; charge cancels if firer takes a hit | +20 |
| 5 | **Quake Wave** | area (track-crawling) | wave travels *along the track surface* forward 250 m at 70 m/s, full width, lifts + damages everyone it passes | 15 + airborne pop | jump it via pad/edge; it's slow and visible (Wipeout Quake) | +25 |
| 6 | **Leech Beam** | drain | tether to craft ahead ≤25 m for up to 4 s: −4/s them, +4/s you, they see the beam | 16 total | break line-of-sight / range; sideshift | +10 |
| 7 | **EMP Shockwave** | area (radial) | 12 m radius burst around firer | 12 + boost/items locked 2.5 s | anti-cluster tool; don't bunch | +14 |
| 8 | **Aegis Shield** | utility | absorbs next 40 dmg or 5 s, blocks mines/missiles, no ram bonus | — | wait it out; mines still block path | +22 |
| 9 | **Flare (countermeasure)** | utility | breaks all locks on you, destroys projectiles/mines within 10 m, 1.5 s window | — | bait it with a fake lock, then fire | +12 |
| 10 | **Surge Cell** | pickup | instant +30 energy | — | — | (is energy) |

Design notes: the one near-race-ender (Rail Lance 30) is gated by a long telegraph and self-aim — the "hard aim + charge time" pattern that keeps Wipeout's Plasma fair (Exa: wipeout.wiki weapon taxonomy). Quake is mid/back-only (see table below) because it's the strongest catch-up tool and leaders wielding it is miserable. No blue-shell analog: position-targeted nukes are the most-resented catch-up device; distance-bucketed *odds* do the job invisibly (Exa: Mario Kart 8 item-probability documentation; gamedeveloper.com rubber-banding critique).

### 4.3 Pickup placement and distribution

**Spatial model: Wipeout pads, not Mario boxes.** Item pods sit on the track surface in authored rows (2–3 across the width, offset so taking one costs a small line deviation); a taken pod **disables for 4 s** then respawns — pod-taking is itself contested (Exa: wipeout.wiki — race-mode pads disable after use). Authored per track in `TrackDef.itemPods: {t, lateral}[]` — Neon Orbital gets 9 rows (after the start straight, mid-climb, hairpin exit, flyover entry, carousel exit…), never inside the hardest corner (pickup decisions shouldn't stack on survival decisions).

**Distribution: distance-bucketed odds keyed to gap-from-leader** (the MK8 mechanism — buckets by distance behind frontrunner, separate human/AI tables; Exa: mariowiki item-probability tables):

| Gap to leader (track meters) | Pulse | Missile | Mine | Rail | Quake | Leech | EMP | Shield | Flare | Surge |
|---|---|---|---|---|---|---|---|---|---|---|
| Leader / <120 m | 20 | 5 | 22 | 8 | — | — | 5 | **18** | **14** | 8 |
| 120–450 m (midfield) | 14 | **20** | 10 | 10 | 8 | 8 | 8 | 8 | 6 | 8 |
| >450 m (tail) | 8 | 18 | 4 | 8 | **16** | 10 | 8 | 4 | 4 | **20** |

(Rows sum to 100. AI uses a flattened variant with no Quake and −50% Surge — CPUs get weaker catch-up items, per MK8's separate CPU tables.) Distribution is rolled server-side with `ctx.random` in multiplayer (§6), locally with the seeded sim RNG offline (§10 determinism).

### 4.4 Boost/shield/countermeasure interplay

Rock-paper-scissors: Missile > plain running; Flare > Missile/Mine; Shield > burst damage but you can't fire while shielded (holding it has cost); EMP > clustered shield-campers (damage ignores shield's *item* nature? — no: shield absorbs it; EMP's value is the boost lockout); Leech > Shield (drains through? **no** — blocked, else shield is dead weight; Leech's value is it can't be flared). Absorb underpins all of it: a cornered leader converts a Pulse into +12 energy and boosts away. Every item has ≥1 counter and ≥1 situational best-use; the balance sim in §10.4 measures pick-vs-win-rate deltas.

### 4.5 Implementation notes (client sim)

Projectiles are **not dynamic Rapier bodies**: each is a kinematic point advanced in the fixed tick with a `world.castRay` sweep per step (or shape-cast for missile 0.4 m radius), colliding with hull group only; walls kill projectiles (except Quake, which follows the surface via track-frame lookup — it's a track-space entity, trivially: `s += 70·dt`). Mines are static sensors. Hit application: victim takes damage + impulse in the same tick, VFX event emitted to the render layer. All combat math lives in `src/sim/weapons/*` as pure functions with vitest coverage (damage tables, lock-cone math, arming/fuse timers). Multiplayer authority for all of this: §6.4.
## 5. AI racers

### 5.1 Racing line: lateral-offset representation (Game AI Pro pattern)

Store the line as a **lateral offset per track sample** on the existing 512-sample center-line — the exact representation Game AI Pro ch. 39 recommends over full splines ("piecewise-linear + interpolation usually wins"; splines define curvature exactly but need iterative registration) (Exa: gameaipro.com ch. 39 PDF). Generation is offline (a script writing `content/tracks/<id>.line.json`, checked in):

1. Init offsets = 0. Iterate ~400 relaxation passes: for each sample, move the offset toward the point minimizing local curvature of the offset polyline (classic shortest-path/curvature smoothing), clamped to ±(width/2 − 2 m).
2. Compute per-sample **target speed**: `v(s) = min(vMax, sqrt(aLat · r(s)))` with lateral budget `aLat ≈ 32 m/s²` (fits the tuned grip), then backward-pass to respect decel limits (`aBrake ≈ 20 m/s²`) so the AI brakes *before* corners.
3. Store `{offset, targetSpeed}` per sample + precomputed racing-line world points.

Rejected: recording human laps as the line (kinky data needing smoothing, blocks new tracks on a human — Exa: ch. 39 notes recorded lines contain kinks); on-line optimization at load (a 400-pass relax on 512 samples is milliseconds, but checked-in JSON keeps it inspectable and diffable).

### 5.2 Driver controller: same craft, same forces

AI racers are full `SimWorld` racers with the identical `computeCraftForces` path — the AI produces a `CraftInput` (steer/thrust/drift/boost/items), never teleports, never gets different physics. Fairness is structural, and every AI improvement is automatically a bot-QA improvement (§10).

Steering: **rabbit-chase** — aim point advanced along the racing line by `lookahead = clamp(0.55 s × speed, 8, 34 m)` (speed-proportional lookahead kills weaving — Exa: ch. 39 "runner/rabbit"), steer = PD on heading error to the rabbit (`kP 2.2, kD 0.35` starting values) through the same `approachSteer` smoothing as the player. Throttle: PI toward `targetSpeed(s_ahead)` sampled at braking-distance lookahead; drift engaged when |heading error| > 0.35 rad at speed > 70% max; sideshift as dodge (below). Stuck detection: progress < 2 m over 2 s → reverse 0.8 s toward line (rare with walls, but required for QA soak).

### 5.3 Difficulty tiers & rubber-banding

F-Zero GX's CPU model is the template because it's continuous and invisible: CPUs vary an **analog throttle by signed time-gap to the player**, capped at ±1.5 s of effect (Exa: fzerogx-docs cpus.md — Novice 0.45 ahead/0.85 even/0.98 behind; Master 0.7/0.96/1.03). Ours:

```
gapS   = (playerProgress − aiProgress) / avgSpeed   // signed seconds, clamp ±1.5
band   = clamp(gapS / 1.5, −1, +1)                  // −1 = AI ahead … +1 = AI behind
throttleScale = tier.base + tier.gain × band        // dead zone: |gapS| < 0.4 → band = 0
```

| Tier | base | gain | effective range | line accuracy noise | item reaction delay |
|---|---|---|---|---|---|
| Rookie | 0.86 | 0.06 | 0.80–0.92 | ±0.9 m offset noise, 0.5 Hz | 1.2 s |
| Veteran | 0.93 | 0.05 | 0.88–0.98 | ±0.45 m | 0.7 s |
| Ace | 0.97 | 0.05 | 0.92–**1.02** | ±0.2 m | 0.35 s |

Principles from Game AI Pro ch. 42 (Exa: rubber-banding chapter): **modulate skill before power** (Rookie/Veteran slow-down manifests as earlier braking + wider lines via `targetSpeed × throttleScale`, not visible speed hacks), keep a **dead zone** around the player so banding is never visible side-by-side, clamp AI advantage to barely-superhuman (Ace 1.02 max — GX goes to 1.3 in story mode and it reads as cheating), and apply pack-level anti-bunching (leading AI pack shares the slowdown based on average position, so the field stretches naturally). Item-based catch-up does the rest (§4.3 distribution buckets) — the approach players tolerate far better than speed cheats (Exa: Polygon on Mario Kart World adaptive-AI backlash; gamedeveloper.com rubber-banding-as-design-requirement).

### 5.4 Combat item usage (`itemBrain.ts`)

Rule-based with tier-scaled reaction delay (no utility-AI framework needed at this roster size):

- **Missile/Pulse/Rail:** fire when lock/aim conditions met AND target gap < weapon envelope AND own line is straight-ish (|curvature| below threshold) — AI shouldn't throw its corner to shoot.
- **Mine:** drop at corner-apex samples when position ≤ 3 (leader logic), else drop on straights behind.
- **Quake/EMP:** Quake when ≥ 2 racers within its 250 m run; EMP when ≥ 2 crafts within 14 m.
- **Shield:** on incoming-lock warning (tier delay) or energy < 25 entering a combat cluster. **Flare:** on missile launch warning, reaction-delayed — Rookies eat missiles, Aces flare ~70%.
- **Absorb:** if energy < 20 and held item's absorb value ≥ 12, absorb instead of fire (the same fire-vs-heal decision players face; keeps AI on the economy).
- **Boost:** energy > 55 AND (straight ahead ≥ 120 m OR gapS > 0.6 behind); never below 20 energy except final half-lap (all-in finish logic, GX-style scout-then-spend arc).

### 5.5 AI in multiplayer

v1 multiplayer is humans-only (§6.6 staging). Phase 7 backfill: the **race host** (first participant, server-designated in the `race` row) simulates AI racers locally and publishes their transforms — the `transform.authority` column already exists precisely for this shape (`module/src/index.ts:52`), so the server accepts AI rows where `authority = host identity`, and combat treats them like any racer. Host migration = new host re-seeds AI from the last server state (positions/energy in tables). This is deliberate scope-deferral: it needs zero new physics but real edge-case work (host disconnect mid-missile), so it ships after human-MP is stable.

---

## 6. Multiplayer via SpacetimeDB

### 6.1 What SpacetimeDB is (and is not) for this game

SpacetimeDB = tables + transactional reducers + scheduled ticks + subscriptions; **no physics engine, no float-heavy sim loop server-side** (Ref: spacetimedb.com docs — module model; scheduled reducers are "best-effort… may be slightly delayed under heavy load", ~20 Hz ticks are the normal pattern). So the server can *arbitrate* (validate, sequence, decide) but not *simulate rigid bodies*. The architecture embraces that split:

| State | Authority | Mechanism |
|---|---|---|
| Movement/transforms | **Owning client** | `publish_transform` at 15 Hz + server plausibility validation (speed cap, jump cap, finiteness) — already implemented (`module/src/index.ts:175-207`) |
| Race progression (gates, laps, finish, timing) | **Server** | `cross_checkpoint` reducer, in-order + min-split validation — already implemented |
| Lobby/ready/countdown/grid | **Server** | existing reducers + scheduled `start_race` |
| **Energy, damage, death, respawn** | **Server** (new) | combat reducers + 20 Hz scheduled combat tick (§6.4) |
| **Item pods, inventory, item rolls** | **Server** (new) | `take_pod` reducer + `ctx.random` rolls (deterministic server RNG — Ref: module/CLAUDE.md ReducerContext) |
| Projectile flight | **Server in track-space** (new, §6.4) | rows advanced by the combat tick; clients render predictively |
| VFX/audio/trails | Client-only | from row changes + event tables |

### 6.2 Client prediction & reconciliation — deliberately minimal

Own craft: fully client-simulated; nothing to reconcile because the server never overrides own-movement (only rejects implausible rows — and the existing respawn-flag self-heal (`f61aa75`) already handles re-sync). Remote crafts: the existing 120 ms interpolation buffer with Hermite (position+velocity) interpolation is the right call and stays (`transformSync.ts:82-104`). Raise publish rate 15 → **20 Hz during racing** (matches combat-tick granularity; 8 racers × 20 Hz = 160 reducer calls/s is trivial relational load). Rejected: server-authoritative movement with client prediction+rollback — requires server physics (unavailable) or trusting one client as physics host (single point of cheating/latency); rejected: lockstep (§1.3).

Anti-cheat posture v1, stated honestly: **plausibility rails, not proof** — speed/jump caps, server-side gate ordering, server-side combat resolution and item rolls (clients cannot grant themselves items, hits, energy, or laps; they *can* fake their own position within plausibility bounds). That is the right cost/benefit for a browser arcade racer without a server sim; document it in `module/AGENTS.md`.

### 6.3 Schema v2 (additions)

```
participant += energy: t.f32(), status: t.enum('alive'|'dead'|'finished'),
               died_at: t.option(t.timestamp()), death_seq: t.u32(),
               item: t.option(t.u8()), position: t.u8()   // standings, server-computed at tick
race        += host: t.identity(), track_id: t.string(), mode: t.string()
projectile   (new): id autoInc, kind: t.u8(), owner: t.identity(),
               target: t.option(t.identity()),  s: t.f32(), lateral: t.f32(),
               speed: t.f32(), ttl_ticks: t.u16()
pod_state    (new): pod_idx: t.u16() PK-ish per race, disabled_until: t.option(t.timestamp())
combat_tick  (new scheduled table): ScheduleAt.interval(50ms)  // 20 Hz
hit_event    (new, event table): victim, attacker, kind, dmg, x,y,z
kill_event   (new, event table): victim, attacker, kind
```

Event tables are the documented fit for transient broadcast (rows never enter the client cache; only `onInsert` fires — Ref: module/CLAUDE.md "Event Tables"): hit sparks, kill feed, pod-take flashes.

### 6.4 Server-side combat in track-space (the key novel piece)

Because every weapon in §4 is expressible in **track coordinates** (arc-length `s`, lateral offset), the server can resolve combat with pure arithmetic — no physics engine:

- Client `fire_item` reducer: validates sender holds the item, rate-limits, inserts a `projectile` row (missile stores `target`), or applies instant effects (EMP: radial distance check on current transforms; Rail: corridor check `|Δlateral| < 1.2 m` within 300 m ahead after the telegraph delay; Leech: tether row).
- `combat_tick` (20 Hz scheduled reducer; guarded by the module-identity check the codebase already uses at `module/src/index.ts:91-95`): advances each projectile `s += speed·dt` (missile also steers `lateral` toward target's lateral at its turn rate, and its `s`-speed tracks the gap), checks hits against participants' latest track-coords (server derives `(s, lateral)` from each `transform` row via a **server-side copy of the track sample table** — a ~30 KB constant baked into the module per track), applies damage to `participant.energy`, inserts `hit_event`/`kill_event`, sets `status='dead', died_at, death_pos`, schedules nothing extra — the same tick re-spawns any `dead` participant whose `died_at + 1 s ≤ now` (server-arbitrated **exactly-1-second respawn**, matching the brief; clients render the countdown from `died_at`).
- Tolerances absorb the 15–20 Hz transform staleness: generous hit radii (Δs ≤ 4 m, Δlateral ≤ 2.5 m) — arcade-correct, and identical for all clients because only the server decides.
- Client-side: firer plays muzzle/projectile VFX immediately (optimistic); the authoritative projectile row drives the visible projectile for everyone (interpolated like ghosts); mismatch window ≈ RTT + ≤ 50 ms tick — acceptable at arcade tolerances.

Rejected alternatives: **shooter-client hit claims** (server can't verify → aimbot-grade cheating for free; also produces divergent kill feeds), **victim-client hit detection** (victims deny hits), **host-client combat authority** (single trusted client — acceptable later for AI transforms where stakes are low, not for damage).

Respawn arbitration detail: server stores `death_s`/`death_lateral` (projected to the §4.1 clamped cross-section at death time), and `publish_transform` accepts the >30 m jump only when the row transitions dead→alive and the new position is within 6 m of the stored respawn point — the respawn flag mechanism already in the protocol (`respawn: t.bool()`) becomes server-verified rather than client-asserted.

### 6.5 Latency & rates budget

Transforms 20 Hz × 8 racers; combat tick 20 Hz; projectiles ≤ 24 rows live; subscriptions stay the current four + `projectile` + `pod_state` (+ event tables, cache-free). Expected perceived delays: remote craft ≈ RTT/2 + 120 ms buffer; own hit registration ≈ RTT + ≤ 50 ms; respawn exactly 1000 ms server-time (client shows a 1 s death cam, so network jitter hides inside the fixed beat). Maincloud for prod, `spacetime start` local for dev (Ref: spacetimedb.com hosting docs); measure RTT from EU/US in the P7 latency test before launch claims.

### 6.6 Lobby/matchmaking scope (realistic v1)

Staged, per the brief's instruction to be realistic:

- **M-A (now → Phase 5):** single global room (exists). Add: track vote, per-player energy/status in lobby list, spectate-after-death toggle, "race again" reset (exists as reducer).
- **M-B (Phase 7):** named rooms — `race` becomes multi-row (schema already keys `participant.race_id`; today's code hardcodes `race[0]` in ~5 client sites — a contained refactor), lobby list screen, 8-player cap per room, quick-join.
- **Not v1:** skill matchmaking, persistent accounts beyond SpacetimeDB identity, spectator streams, cross-region sharding. Auth: keep anonymous identity tokens (localStorage) until accounts matter (Ref: spacetimedb.com identity docs — OIDC providers exist when needed).
## 7. Cyberpunk art direction

### 7.1 Palette (codified in `content/palette.ts`, lint-checkable)

Research-backed formula: dark low-purity base covering 70–85% of the frame, full-saturation accents on small areas, 80/15/5 base/surface/accent split, **max 2–3 neon hues per scene**, never pure #000/#FFF, color encodes state (Exa: game color-palette guides + synthwave palette references; Tron canon).

| Role | Hex | Usage |
|---|---|---|
| Void base | `#0B0F1A` / `#0D0818` | sky base, fog far color, HUD panel bg |
| Surface | `#1C1B22` slate (ribbon), `#141821` steel (walls) | the 15% |
| **Cyan** `#00F5FF` | edge lights, checkpoints, safe/interactive, self HUD | signature hue #1 |
| **Magenta** `#FF2DAA` | wall stripes, threats, enemy locks, weapons | signature hue #2 |
| Violet `#7C4DFF` | skyline haze, holograms, fog tint | atmosphere only |
| Mint `#15FFB5` | pickups/energy/recharge strips | reward channel |
| Alert `#FF1744` | damage, low-energy, wrong-way | danger channel |
| Amber `#FBBF24` | countdown, mini-turbo charge | anticipation |

Track colorways: Neon Orbital = cyan/magenta night (current); Vector Sunset = magenta/violet dusk with sun-grid horizon (`#FF2DAA→#7C4DFF` gradient sky plate, gold rim light). Current Tailwind colors (`#22d3ee`, `#e879f9`, `#f0abfc`) migrate to these — close cousins, one sweep.

The look is **emissive-vs-ambient**: nearly-unlit dark world + authored emissive strips that bloom (Exa: cyberpunk visual-language digest — "the dark base is what makes accents float"). Practical rule from the AAA-graphics skill: bloom only catches *authored* emissives (threshold 0.85 stays); never use bloom/fog to hide missing geometry (an automatic scorecard failure — skills digest: visual-scorecard.md).

### 7.2 Lighting

Night scenes: HDRI/equirect env for reflections (exists), one dim directional for shape, ambient 0.5–0.6, **shadows demoted to a quality setting** (at 60+ m/s nobody reads a 1024-map shadow; the skill budget allows ≤2 shadow lights but spending it here is poor ROI — default ON desktop / OFF when PerformanceMonitor declines). Emissive materials carry the scene. Boost pads/recharge strips/item pods each get a fake ground-glow quad (additive sprite), not point lights — **zero dynamic point lights on the track**; light is painted, which is both the aesthetic (Tron/Distance edge-light language — Exa) and the perf strategy.

### 7.3 Post-processing stack & frame budget

Stack (one `EffectComposer`, effects merge into minimal fullscreen passes — Ref: postprocessing docs "EffectPass automatically organizes and merges"):

| Effect | Params | When | Est. cost 1080p mid-GPU |
|---|---|---|---|
| Bloom | mipmapBlur, threshold 0.85, intensity 0.75→0.9 | always | ~0.8–1.2 ms (mip chain is the real cost) |
| Vignette | 0.25, darkness 0.65 | always | merged ≈ free |
| ChromaticAberration | offset 0→0.0025, **event-driven**: boost engage, hits, respawn | pulses only | merged ≈ free |
| Noise/Scanline | opacity 0.02 | always (subtle CRT) | merged ≈ free |
| SMAA | — | when `multisampling=0` (low tier) | ~0.5 ms |
| ToneMapping | ACES | always | merged |

`multisampling={4}` desktop default; drop to 0 + SMAA on decline; `resolutionScale` 0.75 as the second lever (Ref: react-postprocessing EffectComposer docs — multisampling & resolutionScale are the documented levers). **Motion blur: rejected** — the library ships none (Ref: postprocessing effect inventory), and the research says it wouldn't help: Disney's Split/Second study found no measurable effect on enjoyment/perceived speed, and ArtsIT 2016 found strong blur *decreases* perceived velocity (Exa). Budget: post ≤ 2.0 ms desktop / ≤ 1.2 ms mobile-class (skills digest: ≤2 post passes beyond render+output).

Speed lines: a screen-space radial-streak shader on a fullscreen triangle inside the scene (not a composer pass), opacity keyed to speed > 80% — sparing the center (Exa: layered speed effects digest).

### 7.4 Set dressing & ship livery

Instanced prop kits, all already downloaded: `pm-tomb-chaser-2` (`Ad01–06` neon ad boards, columns, `Cyber_Surroundings_01`, electric boxes) for street-level clutter; `pm-aero-system` (station rings, floating islands, airship) for mid-distance silhouettes; Quaternius space kit (87 models: planets, stations) for sky objects; Kenney barriers (exists). Add: holographic gantries (double-sided additive quads, scrolling shader), searchlight cones (billboard), distant traffic streams (one `InstancedMesh` of emissive dashes advected along a secondary spline — pure vertex-shader motion, 1 draw call). Billboards keep the Grok-generated art (exists) plus 4 new pieces (asset table §8.4).

Ships: base = Quaternius ships (multiple in the kit). Livery = per-player `color` (exists for ghosts) evolved into a proper 3-tone scheme: body tint, emissive trim mask, engine glow color. Trim masks are generated 1K textures (image pipeline). Hero-ship upgrade: **one Tripo text-to-3D hero craft** for the player-default ship (the AAA-graphics skill's sourcing rule: hero surfaces may not stay procedural/kit without a logged blocker — skills digest: threejs-aaa-graphics-builder SKILL.md; command + cost in §8.4). Every craft: engine trail (ribbon mesh, additive, length ∝ speed), heat-haze sprite behind nozzles, damage state = emissive flicker + smoke sprites below 25 energy (2-channel state telegraphy per HUD rules).

### 7.5 HUD / UI style

Skill rules adopted wholesale (skills digest: hud-readability checklist): **fixed-width stable containers** (tabular-nums already in use), critical changes telegraph on ≥2 channels, HUD stays out of the focal center and threat lanes, more than one HUD state (race, pause, results, spectate, settings).

Layout (1080p reference, rem-scaled): top-left lap/time cluster (exists); top-right **position `3/8`** big + kill feed under it (3 rows, 4 s fade); bottom-center speed (exists) flanked by **energy bar** — segmented, mint→amber→alert gradient, boost-drain region ghosted, 20%/10% pulse+tone warnings (Wipeout's warning convention — Exa: wipeout.wiki shield states); bottom-right **item slot** hexagon with absorb-hold radial progress; bottom-left minimap (§2.5); center reserved for countdown/GO (exists), lock-on warning = thin magenta screen-edge flash + rising tone (2 channels), wrong-way indicator. Typography: bundled `Orbitron` (headers/speed) + `IBM Plex Mono` (timers) as woff2 in-repo — no CDN fonts (offline-safe, CSP-safe). Menus: same panel language as the existing lobby card (border-cyan/black-blur — keep, it already looks right); add title screen with ship-on-pad 3D backdrop (reuses race scene assets, `frameloop="demand"` when paused — Ref: r3f scaling-performance docs).

Diegetic-lite flourishes: 1–2° HUD skew, scanline overlay at 2% opacity, glitch tick on damage. Nothing animated at >4 Hz persistently (readability at speed; Redout's faint-HUD failure is the anti-pattern — Exa: pietriots Redout analysis).

---

## 8. Audio

### 8.1 Direction

Synthwave-industrial: saw-bass music beds, analog-style engine hums, chunky digital weapon transients, clean UI blips. Mix hierarchy (ducking): announcer/warnings > impacts on self > own weapons > music > remote SFX > ambience. Master `DynamicsCompressorNode`; groups `master/sfx/ui/music/engine` (the audio skill's group convention — skills digest: threejs-audio-generator).

### 8.2 Sourcing routes per category

Constraint discovered in research (skills digest: threejs-audio-generator SKILL.md): **ElevenLabs = SFX/ambience only — no music endpoint; `--duration` 0.5–30 s; `--loop` for seamless 8–30 s beds.** So:

| Category | Route | Notes |
|---|---|---|
| Engine (idle/mid/high loops ×3, boost layer) | **ElevenLabs `sfx --loop`** (8–12 s beds) | crossfaded bands + playbackRate 0.85–1.5 within each band (Ref: three.js Audio docs — playbackRate is the standard engine-pitch mechanism); prompt-influence 0.3–0.55 per skill guidance |
| Weapons (7), impacts, explosion, shield, flare, pod pickup | **Kenney CC0 packs first** (Sci-Fi Sounds, Impact Sounds, Interface Sounds — same trusted CC0 source as existing models), **ElevenLabs `sfx`** for the ~6 that need bespoke character (missile lock/launch, rail charge, quake rumble, EMP, absorb slurp, respawn burst) | 0.5–2.5 s, prompt-influence 0.55–0.8 |
| UI (hover, confirm, countdown beeps) | Kenney Interface Sounds (CC0) | |
| Announcer ("3-2-1-GO", "FINAL LAP", "YOU'RE DESTROYED", position calls) | **ElevenLabs `tts`** (skill supports TTS; `voice-change` if we want acted grit) | 8–10 lines v1 |
| Music (menu loop + 2 race tracks) | **CC0/CC-BY synthwave from OpenGameArt / Free Music Archive** (credits in README like existing assets); fallback if nothing fits: layered ElevenLabs 30 s `--loop` pulse beds as interim | Honest gap: no generator in our stack does real music; license-vetted CC is the free-first route the brief asks for |
| Ambience (city hum, tunnel reverb zone, crowd pass) | ElevenLabs `--loop` beds | tunnel = ConvolverNode small IR, dry/wet by track section |

### 8.3 Runtime architecture

`audio/engine.ts`: 3-band crossfaded loops on `THREE.Audio` (self) — self engine is non-positional (always centered); remote crafts get `THREE.PositionalAudio` engine loops, `refDistance 20`, capped to the nearest 4 remotes (voice budget). Doppler: real doppler is gone from WebAudio/three; fake it — remote engine playbackRate += clamp(relativeApproachSpeed × 0.004, ±0.12) (Ref: three.js PositionalAudio docs; WebAudio doppler deprecation). Autoplay: resume `listener.context` on the lobby Join/Start click (Ref: MDN/Chrome autoplay policy via docs digest — context starts suspended until a gesture). SFX pooling: 12-voice round-robin per category, pitch-varied ±6% per shot (skills digest game-feel.md number). All event-driven from `simEvents` — audio never reaches into React.

### 8.4 Full asset list with sourcing route (brief requirement)

**Models** (existing pipeline `assets:fetch`/`optimize` unless noted): player hero ship — **Tripo text-to-3D** (`threejs_3d_asset.py text --prompt "game-ready anti-gravity racing craft, sleek forward-swept hull, cyberpunk neon trim, PBR" --texture-quality detailed --wait --download`, ~30 credits, GLB; skills digest: threejs-3d-generator); 3 rival ship variants — **Quaternius space kit** (exists, pick + livery); track props (pylons, gantry, barrier, pod, pad) — **Kenney/procedural instanced** (support surfaces may stay procedural per sourcing rule, logged); city clutter — **pm-tomb-chaser-2** (exists); sky objects — **Quaternius planets** (exists).

**Textures/images**: skyline rings ×2 (exist, Grok-generated), sunset sky gradient + sun-grid plate — **Grok `/imagine`** (per brief; the installed Gemini-based threejs-image-generator is the equivalent fallback route — both are in the toolbox, Grok matches the existing `public/assets/gen/` provenance), 4 new billboard ads — **Grok `/imagine`**, ship trim/emissive masks ×3 (1K) — **image generator**, chevron/decal atlas — **hand-authored SVG→PNG** (crisp vector shapes beat generation for signage), PBR track/wall sets — **ambientCG** (exist: Asphalt006, Road007 fetched, MetalPlates006), HUD icons (10 items + status) — **hand-authored SVG** (UI needs pixel-exact consistency; generators for icon sets produce style drift).

**Audio**: per §8.2 table. **Fonts**: Orbitron + IBM Plex Mono woff2, OFL, vendored.

Everything generated lands in `public/assets/gen/` with provenance lines appended to README's credits table (pattern exists) and the sourcing ledger the graphics skill requires.
## 9. Performance budgets

### 9.1 Targets & budgets

Primary target: **60 fps at 1080p on a mid-tier 2019+ laptop GPU** (M1 / GTX 1650 / Iris Xe class); graceful degradation to 40 fps on older iGPUs via adaptive tiers; 120 fps uncapped on dGPUs (fixed 60 Hz sim + interpolation decouples feel from fps — Ref: react-three-rapier fixed timestep + interpolation). Mobile is **out of scope for v1** but budgets keep the column so the door stays open.

Adopt the AAA-graphics skill's budget contract verbatim as the CI-checked numbers (skills digest: technical-art.md):

| Metric (worst active-play view) | Desktop | (Mobile, future) |
|---|---|---|
| Draw calls (`renderer.info.render.calls`) | ≤ 300 | ≤ 150 |
| Triangles | ≤ 750 k | ≤ 300 k |
| Geometries / Textures | ≤ 300 / ≤ 60 | ≤ 200 / ≤ 40 |
| Texture memory | ≤ 256 MB | ≤ 128 MB |
| Shadow lights / map | ≤ 1 × 1024 (quality setting) | 0 |
| DPR cap | 2.0 | 1.5 |
| Post passes beyond render+output | ≤ 2 (composer merges the stack — §7.3) | 0–1 |
| Physics step | ≤ 3 ms (8 crafts × 4 rays + trimesh ribbon + 512 wall cuboids + ≤24 projectile sweeps) | — |
| Frame total | ≤ 12 ms render + 3 ms physics + 1 ms sim/JS | — |

Budget overruns are allowed only with a written tradeoff note (skill rule), and the per-PR CI report (§10.5) prints the deltas.

### 9.2 Strategy

- **Instancing sweep (Phase 5.3):** audit `Scenery.tsx` — barriers are capped instanced already; convert pylons/gantries/pods/ads to `InstancedMesh` (1 draw call per kit piece — Ref: r3f scaling-performance docs; drei `<Instances>` / `<Merged>` for the declarative cases). Distant traffic = 1 instanced mesh with vertex-shader motion (§7.4). Track ribbon/walls/stripes are already single merged geometries — keep.
- **Textures:** add KTX2/BasisU (UASTC for normals, ETC1S for albedo) to `optimize-assets.mjs` via gltf-transform + standalone `toktx` for loose textures; load with drei `useKTX2` (Ref: drei loader docs) — biggest VRAM/bandwidth lever; the 2K JPG PBR sets currently decode to ~48 MB VRAM each set.
- **LOD:** drei `<Detailed>` on ships (full / 60% / billboard at 40/120 m) and kit props; hysteresis gaps to prevent popping under motion (skills digest: LOD guidance — verify transitions while moving, not in orbit).
- **Adaptive tiers:** `<PerformanceMonitor>` drives: DPR 2→1.5→1.25 → `resolutionScale` 0.75 → shadows off → multisampling 0+SMAA (Ref: drei PerformanceMonitor / r3f `performance.regress`). Tier changes logged to diagnostics so QA sees them.
- **Allocation discipline:** already good (scratch vectors); the sim tier keeps it law: preallocated pools for projectiles/FX/events; heap-growth check in the soak test (§10.4).
- **Physics:** wall cuboids 512 total is fine (fixed body, broadphase-cheap); projectiles as queries not bodies (§4.5) keeps island count flat; `maxCcdSubsteps` stays 1, CCD only on crafts.

---

## 10. QA and verification

The debug bridge (`window.__KZERO_DEBUG`) already exposes `setInput/getState/teleport/getRace/respawn` — it becomes the formal test contract, extended per the QA skill's hook conventions (skills digest: threejs-qa-release — `seed()`, `setState()`, `setPausedForScreenshot()`, `setReducedMotion()`, `hideDebugUi()`, plus diagnostics counters: frame/tick counts, entity counts, renderer.info dump).

1. **Unit (vitest, in `src/sim/` + `shared/`):** steering envelope (exists on fix branch — extend), grip/redirect invariants, energy drain/charge/kill-refund arithmetic, item distribution tables (rows sum to 100; bucket selection), lock-cone math, respawn = exactly 60 ticks with pose projected into track bounds, progress monotonicity on synthetic paths, racing-line generator (offsets within width, target speeds respect aLat/aBrake). Track-space hit math lives in a `shared/` pnpm workspace package consumed by **both** the client sim and the SpacetimeDB module, so server combat math is unit-tested without spinning up spacetime.
2. **Replay determinism (vitest + Playwright):** record per-tick input logs; same seed + same log ⇒ same final `(position, lap, energy)` hash **on the same machine** (Rapier WASM is deterministic per version/inputs — Ref: rapier.rs determinism page; we deliberately don't claim cross-machine). This is the bug-repro workhorse and, later, free ghost laps.
3. **Playwright smoke (CI, headless, `workers: 1`):** boot → canvas present → zero console errors → `__KZERO_DEBUG` ready → `setInput({thrust:1})` → speed > 20 within 3 s → gate 1 crossed. Config notes from the skill: single worker (shared SwiftShader flakes in parallel), and **never report headless FPS** — headless renders on SwiftShader at ~2 fps; functional assertions only (skills digest: playtest-bot.md).
4. **Bot playtests (the big one):** the §5 AI driver *is* the bot. CI gates: Ace bot completes 3 laps on every shipped track, zero wall-stuck (`softlockWindows = 0`), lap time within per-track min/max band (catches both broken physics and broken tracks); **fairness probe** adapted from the skill's two-reaction-level test: Rookie-vs-Ace lap delta must exceed 4 s (difficulty is real, not decorative); combat soak: 8 bots, 5 min, assert kills > 0, respawns all exactly 60 ticks, heap growth < 10 MB, zero NaN transforms. Balance harness (Phase 2.6/3.5): headless bot duels sweep item matchups → win-rate/pick-rate CSV; flag any weapon with kill-share > 30% or < 5%.
5. **Visual regression + canvas inspection:** 4 seeded, physics-paused states (start grid, hairpin apex mid-race, combat cluster with FX, results screen) via `seed()`+`setState()`+`setPausedForScreenshot()`; Playwright `toHaveScreenshot` with lenient WebGL thresholds; plus the packaged canvas-pixel inspector (`inspect-threejs-canvas.mjs --url … --state active-play --seed N`) whose measured metrics catch the exact bug class this repo just had ("track not visible"): `colorEntropyBits ≥ 3.0`, `dominantColorShare ≤ 0.6`, `edgeDensity ≥ 0.04`, `luminance.contrast ≥ 60` (skills digest: qa-release SKILL.md metrics + red-flag thresholds).
6. **Perf gate:** headed local run (or CI GPU runner if available) dumps `renderer.info` via diagnostics at 3 camera stations per track; assert §9.1 budgets; print per-PR delta table. Headless CI still counts draw calls/tris (counting works without a real GPU; only fps doesn't).
7. **Module tests:** reducer-level integration on local `spacetime start` in a nightly job (join → ready → countdown → transforms → checkpoint → finish), not per-PR (keeps PR CI < 5 min).

---

## 11. Phased delivery roadmap

Every item = one PR, sized 0.5–3 days, with acceptance criteria (AC). Dependencies marked →. **Critical path in bold.** The in-flight fix branch (`fm/fix-track-b4`: ribbon visibility, steer sign/rate) is **P0** and everything assumes it merged.

### Phase 1 — Feel: "smooth, fun single-track time-trial" (target: 1–1.5 weeks)

| # | PR | Contents | AC | Deps |
|---|---|---|---|---|
| **1.1** | **Sim extraction** | `src/sim/` skeleton; `computeCraftForces` pure fn; single `SimRoot` `useBeforePhysicsStep`; `CameraRig` extracted; seeded RNG; simEvents ring | Behavior parity (replayed input → lap time ±2%); vitest for craftSim; zero per-tick allocs (soak heap check) | P0 |
| **1.2** | **Feel package** | §3.2 table values; counter-steer ×1.5; coast rule; airbrakes+sideshift (Q/E); airborne pitch; mini-turbo; §3.5 camera (FOV curve+punch, trauma shake, height/distance curves, lookahead, lateral offset); speed-line shader; display multiplier | All §3.2/§3.5 numbers in leva; steering envelope tests; camera never enters walls on T1; subjective sign-off lap | 1.1 |
| **1.3** | **Readability + progress** | Ribbon surface shader (edge glow, flowing grid, decal noise); chevrons from curvature; palette sweep to §7.1; wall proximity glow; `progress.ts` + standings store; minimap canvas | Progress monotonic over replayed lap; minimap tracks; inspector metrics pass (§10.5) on 3 stations | 1.1 |
| **1.4** | **Energy & boost economy** | Energy store; hold-boost (30/s, cap 76); recharge strips (TrackDef + 2 strips on T1); wall damage; HUD energy bar + warnings | Unit: drain/charge/refund rates; wall hit caps at 12; HUD 2-channel warnings | 1.2 |
| **1.5** | **QA foundation** | Debug-bridge v2 contract (seed/setState/pause/counters/renderer.info); Playwright smoke; input record/replay; canvas inspector wiring; CI (workers 1) | Smoke green in CI; replay hash stable ×10 runs; inspector thresholds enforced | 1.1 |
| 1.6 | Audio v1 | Engine 3-band loops + boost layer (ElevenLabs); UI/countdown SFX (Kenney); mixer + autoplay gate | Pitch tracks speed; zero console errors; ducking works | 1.1 (parallel) |

**Exit criteria:** a stranger plays 5 minutes of time-trial on Neon Orbital and doesn't want to stop; Ace-precursor scripted bot laps in CI.

### Phase 2 — Combat (local, vs dummies) (1–1.5 weeks)

| # | PR | Contents | AC | Deps |
|---|---|---|---|---|
| **2.1** | **Destruction & 1 s respawn-in-place** | Death state, explosion FX, 60-tick timer, §4.1 pose projection, 2 s invuln+ghost, fall-out unified into this path (gate respawn removed) | Unit: exactly 60 ticks; pose always inside track; invuln blocks damage; fall at any t respawns on ribbon | 1.4 |
| **2.2** | **Pods, inventory, absorb** | `TrackDef.itemPods` + 9 rows on T1; pod meshes/instancing + 4 s disable; one-slot inventory; §4.3 distribution (seeded); absorb hold 0.6 s; HUD item slot | Distribution unit tests; pod contention correct; absorb refunds per table | 2.1 |
| **2.3** | **Weapons wave 1** | Pulse, Hunter Missile (+lock warning UI/tone), Shock Mine, Surge Cell; kinematic projectile sweeps; static dummy crafts on track | Each weapon: unit tests for envelope math + an e2e bot scenario (fires, hits, damage applied) | 2.2 |
| 2.4 | Weapons wave 2 | Rail Lance (telegraph), Quake (track-space wave), Leech, EMP, Shield, Flare + interplay rules (§4.4) | Same per-weapon AC; flare-vs-missile e2e | 2.3 |
| 2.5 | Combat juice | Hit sparks, explosion pool, kill feed, damage flicker + smoke, trauma hooks, weapon SFX (Kenney/ElevenLabs) | Visual states added to regression set; event→FX latency ≤ 1 frame | 2.3 |
| 2.6 | Balance harness | Headless bot-duel sweeps → win/pick-rate CSV; first tuning pass | No weapon kill-share > 30% or < 5% across sweep | 2.4, 3.2 partial (uses driver) |

### Phase 3 — AI racers (1 week)

| # | PR | Contents | AC | Deps |
|---|---|---|---|---|
| **3.1** | **Racing line generator** | Offline relax script → `content/tracks/*.line.json` (offset+targetSpeed per sample); debug viz overlay | Offsets within bounds; speeds respect aLat/aBrake; line renders in dev | 1.3 |
| **3.2** | **Driver v1 + full grid** | Rabbit-chase steer, PI throttle, drift/sideshift use, stuck recovery; 7 AI on grid; standings live | Ace completes 3 clean laps CI on T1 (no wall-stuck); positions correct vs progress | 3.1, 2.1 |
| 3.3 | Difficulty & rubber band | §5.3 tiers, gap-throttle with dead zone, pack anti-bunching | Rookie-vs-Ace lap delta > 4 s; no visible side-by-side speed cheat (band = 0 inside dead zone test) | 3.2 |
| 3.4 | AI item brain | §5.4 rules + tier reaction delays | Bots use every item type in soak; Ace flares ≥ 60% of missiles | 3.3, 2.4 |
| 3.5 | Bot QA gates | Lap-time bands per track in CI; combat soak (8 bots, 5 min); fairness probe | §10.4 assertions green | 3.2 |

### Phase 4 — Multiplayer combat (1.5–2 weeks)

| # | PR | Contents | AC | Deps |
|---|---|---|---|---|
| **4.1** | **Schema v2** | participant += energy/status/died_at/item/position; race += host/track_id; pod_state; 20 Hz publish; `shared/` package (track tables + hit math) | Module publishes locally; client compiles from regenerated bindings; existing MP race still works | 2.2 (design), 1.4 |
| **4.2** | **Server combat** | `fire_item`, `take_pod` (+`ctx.random` rolls), `combat_tick` 20 Hz (projectiles in track-space, hits, damage), hit/kill event tables | `shared/` math unit-tested; two local clients: A fires, B's energy drops on both screens; server rejects invalid fires | 4.1 |
| **4.3** | **Respawn arbitration** | status dead → 1 s server respawn; death cam; respawn-flag validation vs stored death pos; invuln server-tracked | Two-client test: kill → victim respawns at death spot in 1.0 s ± 1 tick server-time; spawn-kill impossible during invuln | 4.2 |
| 4.4 | MP presentation | Remote fire/hit/kill VFX from events; standings/results from server rows; race-again flow; spectate-after-finish | Kill feeds identical on all clients; results match server finish_ms | 4.2 |
| 4.5 | Latency hardening | RTT probe + jitter-adaptive interpolation delay (100–180 ms); EU↔US playtest matrix; publish-rate fallback 20→10 Hz | Playable at 150 ms RTT (subjective + hit-reg tolerance measured) | 4.3 |

### Phase 5 — Content, art, audio, release polish (2 weeks, heavily parallel)

| # | PR | Contents | AC | Deps |
|---|---|---|---|---|
| 5.1 | Vector Sunset | §2.6 greybox → bot gate → art pass (sunset palette, sun-grid sky via Grok, tunnel) | Greybox gate (bot laps 55–75 s, zero wall-line contact); inspector metrics; regression states added | 3.2 |
| 5.2 | Ships & livery | Tripo hero ship; 2 kit variants; 3 stat profiles (Body/thrust/grip trades); livery trim masks; ship select UI | Ship select works in MP (color+model synced); stat profiles bot-lap within 3% of each other (balanced) | 3.5 |
| 5.3 | Perf pass | Instancing sweep; KTX2 pipeline; LOD; PerformanceMonitor tiers; budgets CI report | §9.1 table green at 3 stations × 2 tracks; tier downgrade path exercised in test | 5.1 |
| 5.4 | HUD v2 + menus | Kill feed/lock/wrong-way polish; pause/settings (audio sliders, quality tier, keybinds); title + track select; results v2 | HUD readability checklist pass; all 6 UI states in regression set | 4.4 |
| 5.5 | Audio v2 | Weapon/announcer set; music loops (CC0 sourced + credits); tunnel reverb; mix pass | Voice budget ≤ 12; announcer fires on events; credits updated | 2.5 |
| 5.6 | Release | prod build + preview verification; base-path check; debug gating (`import.meta.env.DEV` — pattern exists); bundle review; license/credits audit; maincloud deploy + smoke | qa-release checklist green (skills digest: release.md); public URL race completes | all P5 |

### Phase 6 — Stretch (post-v1, explicitly out of launch scope)

RMF frames + track-relative gravity + a loop/corkscrew track 3 (§2.1/§3.1); track hazards (slick/magnet strips); time-trial ghosts from the replay system (1.5 already records inputs); AI backfill in MP via host authority (§5.5); named rooms/lobby browser (§6.6 M-B); gamepad + remappable keys if not landed in 5.4.

### Critical path

**P0 → 1.1 → 1.2 → 1.4 → 2.1 → 2.2 → 2.3 → 3.1 → 3.2 → 4.1 → 4.2 → 4.3 → 5.6** (~6–7.5 weeks single-threaded; ~5 with the parallel lanes: 1.3/1.5/1.6 alongside 1.2–1.4; 2.4–2.6 alongside 3.1; 5.1–5.5 fan out after their deps). The riskiest item is **4.2 server combat** (novel pattern; de-risked by the `shared/` math package and by 2.x proving the same math client-side first). The highest-leverage item is **1.2**: everything after inherits its feel.

---

## Appendix A — research sources used (by section)

**Exa (web research):**
- F-Zero GX mechanics (energy/boost/CPU throttle numbers): speeddemosarchive GX kb, tasvideos GX resources, github.com/JoselleAstrid/fzerogx-docs (energy.md, cpus.md), mutecity.org/wiki/Boost, Smidelov GX multiplayer analysis → §3.2, §3.4, §4.1, §5.3
- Wipeout handling/weapons/absorb: wipeout.wiki (HD page), GameFAQs HD/XL weapon FAQs, wipeout fandom Shield Energy → §3.2, §4.1–4.4
- Hover physics: Unity Hover Racer pattern (discussions.unity.com threads), mads.blog sci-fi-racing p2/p3, Stephen-Callum/VehiclePhysics, BallisticNG physics-stats docs → §3.1
- Sense of speed: shawnhargreaves.com "vrrroom whoosh", ArtsIT 2016 FOV study (eudl.eu), Disney Research Split/Second motion-blur paper, 34bigthings Redout dynamic-resolution writeup, pietriots Redout color analysis, strayspark data-driven camera shake → §3.5, §7.3, §2.2
- AI/rubber-banding: Game AI Pro ch. 39 & 42 PDFs (gameaipro.com), guiguilegui Super Mario Kart rubber-banding disassembly, fzerogx-docs cpus.md, Polygon Mario Kart World adaptive-AI backlash, mattgreer.dev CPU driving, gamedeveloper.com rubber-banding-as-design-requirement → §5
- Item balance: mariowiki MK8 item probability distributions, wipeout.wiki pad behavior → §4.3
- Cyberpunk visual language: coloracci/lospec/synthwave palette references, Distance postmortems (gamedeveloper.com, theverge), pixelfix BallisticNG-vs-Wipeout → §7

**Ref-role (technical docs via Context7 + official-doc fetches; plus repo-local SDK reference):**
- react-three-rapier README/docs (fixed timestep & "vary" warning, interpolation, useBeforePhysicsStep, manual stepping, interactionGroups, InstancedRigidBodies, solver props) → §1.2, §9
- rapier.rs JS user guide (determinism page, forces-vs-impulses semantics, velocityAtPoint, dominance, snapshots, CCD, scene queries) → §1.3, §3.3, §4.5, §6.2
- three.js docs + Curve.js source (CatmullRom curveType, computeFrenetFrames parallel-transport + closed-loop twist smear, arcLengthDivisions/getPointAt cost, TubeGeometry) → §2.1
- r3f scaling-performance + pitfalls docs; drei docs (Instances/Merged, PerformanceMonitor, AdaptiveDpr, useKTX2, useGLTF meshopt) → §1.1, §9.2
- postprocessing / react-postprocessing docs (EffectComposer multisampling/resolutionScale, pass merging, effect inventory — **no motion blur**, Bloom mipmapBlur cost) → §7.3
- spacetimedb.com docs (module model, scheduled reducers best-effort + interval API, subscriptions/row callbacks, event tables, identity/RLS status, maincloud hosting) + `module/CLAUDE.md` SDK reference (tables/reducers/ctx.random/views/event tables) → §6
- three.js Audio/PositionalAudio docs + autoplay policy → §8.3

**Installed skills (checklists/pipelines consulted):** threejs-gameplay-systems (game-feel numbers, fixed-loop order, level-design checklist), threejs-aaa-graphics-builder (budgets, sourcing rules, scorecard), threejs-qa-release (bot playtest, canvas inspector metrics, Playwright caveats, release checklist), threejs-3d/image/audio-generator (Tripo/Gemini/ElevenLabs commands, costs, limits — notably: ElevenLabs has **no music endpoint**, 0.5–30 s, `--loop`), threejs-game-ui-designer (HUD readability rules), threejs-debug-profiler (renderer.info profiling workflow) → §3.4, §7.5, §8, §9, §10.

## Appendix B — deviations & risks called out for cross-review

1. **Respawn-in-place unifies fall-outs** (§4.1): the brief specifies 1 s in-place respawn for *kills*; I extend the same path to fall-outs (projected to center-line at death `s`). Alternative: keep last-gate respawn for falls. I chose unification for one code path + no free rewind-punishment asymmetry; contestable.
2. **Boost drains 30/s vs GX's 16.7/s** (§3.4): hotter economy for short laps; pure tuning, flagged for bot-duel validation.
3. **Server combat in track-space** (§6.4) is the most novel/least-precedented piece; fallback if reducer-tick load or feel disappoints: shooter-client hit claims with server sanity checks (accepting the cheat surface) — a 2–3 day pivot since all math lives in `shared/`.
4. **Display-speed multiplier ×2.2** (§3.5): fiction vs honesty tradeoff; trivially reversible.
5. **No ECS / no zustand** (§1.1): a bet on the existing idiom scaling to ~10 systems; if sim systems proliferate past that, revisit miniplex for *entities only*.
6. **Mobile out of v1** (§9.1): budgets keep the mobile column but no touch input/testing until post-launch.
