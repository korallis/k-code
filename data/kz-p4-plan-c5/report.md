# K-ZERO P4 — Multiplayer v1 on SpacetimeDB Cloud: Implementation Plan

**Task:** kz-p4-plan-c5 (planning scout, no implementation code)
**Worktree:** detached HEAD at `91511a6` ("feat(game): add eight selectable hero ships (#21)")
**Date:** 2026-07-13
**Method:** direct read of `src/`, `module/src/`, `scripts/`, `docs/qa/`, plus targeted greps. Every claim below carries a `file:line` reference into that commit. No code was written; no pushes; no module publishes.

---

## 0. TL;DR

Recommendation: **extend the N0 "validated client-authority" model rather than replace it.** Each client keeps simulating its own craft locally at 60 Hz exactly as today (zero added input latency, preserving the P1.4 feel contract), publishes pose at 15 Hz through the existing `publish_transform`-style validated relay, and SpacetimeDB Cloud becomes the *sole authority for everything discrete*: match lifecycle, lap/checkpoint progress, item pickups, weapon inventory, damage/energy outcomes, kills, respawn tokens, and results. Combat resolves per-weapon: instant area weapons (Arc, EMP-Quake) and the telegraphed Rail resolve **server-side** against transform rows; Mines resolve **victim-side** (the victim reports driving into a server-registered mine, validated against their own published pose); travel-time projectiles (Pulse, Seeker) are **shooter-claimed with server plausibility validation**. Full server physics and cross-client deterministic lockstep/rollback are rejected with rationale in §2 — the deciding facts are that the craft sim is inseparable from Rapier (which cannot run inside a SpacetimeDB module) and that the project's own determinism contract is explicitly "same-build local replay only" (`CLAUDE.md`, Fixed-tick runtime section).

The hard-constraint GAMEPLAY_HASH handshake is designed end-to-end in §3.4: a server `track` table seeded from generated track data, `{compiler_version, gameplay_hash, track_version}` frozen onto each `match` row at creation, `join_match` rejecting mismatched clients, and a client-side `incompatible-version` UI state.

Eight single-PR milestones are laid out in §9, gated by a pre-P4 "P3-exit" PR that closes a real gap found during the audit: the 8-bot balance suite currently covers Neon Orbital only, and two items the task brief lists as landed (AI item use, balance instrumentation) **are not in the tree** (§1.2).

---

## 1. Ground truth audit

### 1.1 What is actually landed (verified)

| Capability | Evidence |
|---|---|
| Fixed 60 Hz deterministic runtime, seeded RNG, body-registration gate, golden hash | `src/game/runtime/GameRuntime.ts:59-388`, `src/game/runtime/constants.ts:2` (`FIXED_HZ = 60`), `determinism/goldenHash.ts`; determinism scope stated as "same-build local replay only" in `CLAUDE.md` |
| Input ring buffer with 11-field quantized intent (incl. `fireWeapon`, `useUtility`) | `src/game/runtime/input/InputIntent.ts:6-32`, `InputRingBuffer.ts:12-93` (sticky consume, overwrite-oldest) |
| Track artifact compiler with compatibility contract `{compilerVersion, trackId, trackVersion, gameplayHash, artVersion}` | `src/game/track/compiler/artifactTypes.ts:15` (`COMPILER_VERSION = 2`), `:201-209`; FNV-1a gameplay hash over quantized fields in `quantize.ts:113+` |
| Two compiled tracks: Neon Orbital (8 gates) and Black Rain Foundry (10 gates) | `src/game/track/catalog.ts:34-55`; gate counts per `src/game/race/raceState.ts:12` comment and `module/src/trackData.generated.ts:9` (`CHECKPOINT_COUNT = 8`) |
| Module data generation for the server (Neon only) | `src/game/track/compiler/cli.ts:28-41` (REGISTRY: only Neon has `moduleDataPath`; Foundry entry commented "Solo/catalog only until match rows carry per-track hashes"), `codegen.ts:24-49` (`emitModuleDataTs` emits TRACK_ID, TRACK_VERSION, **GAMEPLAY_HASH**, CHECKPOINT_COUNT, GRID_POSES) |
| `GAMEPLAY_HASH` exported and explicitly awaiting P4 | `module/src/trackData.generated.ts:7-8`: "Gameplay hash — exported for the future Phase-4 client/server compatibility handshake. In P4, the match row will store version + hash and refuse mismatched clients." Current value `1964167107`, `TRACK_VERSION = 3` |
| N0 SpacetimeDB module (TypeScript, `spacetimedb` 2.6.*): single global race row, lobby/ready/countdown/racing/finished, validated 15 Hz transform relay, server respawn tokens, monotonic idempotent checkpoints, DNF + 15 s reconnect grace, host election, rematch + results lock | `module/src/index.ts:23-127` (tables player/race/participant/transform + 3 scheduled tables + token_counter), reducers at `:337` (join_lobby), `:381` (set_ready), `:419` (start_race), `:471` (publish_transform), `:568` (cross_checkpoint), `:625` (request_fall_respawn), `:644` (request_rematch), `:667` (finish_timeout), `:703` (apply_dnf), `:730` (onDisconnect) |
| Pure mirror of module rules, tested without the CLI | `module/src/rules.ts` (plain-data `MatchDb` + reducer-equivalent pure ops), run inside the root suite: `scripts/test.mjs:54` compiles/executes `module/src/rules.test.js` |
| Cloud target already configured | `module/spacetime.json`: `{"server": "maincloud", "module-path": "."}`; `module/spacetime.local.json`: `{"database": "module-vc9m4"}` |
| Client net layer: connection singleton, snapshot subscriptions, 15 Hz publisher, Hermite-interpolated remote ghosts at ~120 ms delay | `src/net/spacetime.ts:66-108` (URI from `VITE_STDB_URI`, db name hardcoded `"kzero"` at `:74`), `src/net/transformSync.ts:77-153` (publisher `setInterval(..., 1000/15)`), `:159-200` (`interpolateGhost`, `target = now - 120`) |
| Mode containment: Solo never connects; online adapter is sole phase authority | `src/net/matchAdapter.ts:11-38` (LocalMatchAdapter), `:40-109` (SpacetimeMatchAdapter, `forceCountdown`/`forcePhase`/`mirrorProgress`), `src/game/race/raceState.ts:115-206` |
| Full weapon/utility roster, pure fixed-tick, **no Rapier dependency** | `src/game/weapons/combatWorld.ts:1-6` header ("Deterministic with seeded RNG; no Rapier dependency"); Pulse/Arc/Mine/Seeker/Rail/EMP constants `weaponTuning.ts:73-206`; Aegis/Specter/Overdrive/Nanite `:210-250`; central caps `:51-69` (stun ≤ 450 ms, slow ≤ 25 %/1.2 s, 120 ms per-family re-hit immunity, `MAX_DAMAGE_FROM_FULL = ENERGY_MAX - 1`) |
| Energy economy: integer 0–1000, boost drain 120/s, strip recharge 320/s, kill refund +250, respawn energy 500, respawn at death-tick + 60, ghost 15 ticks, grace 60 ticks | `src/game/energy/energyTuning.ts:19-73` |
| Items: two slots, absorb-vs-fire, family pads compiled into artifact, per-socket 5 s respawn, gap-bucket roll tables with an explicitly server-shaped seam | `src/game/items/pickups.ts:1-17`; `roll.ts:29-30` ("Seconds behind leader (server-owned path; offline stub uses local gaps)"); `playerInventory.ts:62-63,190` (`setRaceGapSource`) |
| Racing AI core: pure driver emitting `QuantizedIntent`, tiers, overtake, director; live field of 7 dynamic Rapier opponents; kinematic 8-craft head­less race sim with determinism hash and tier lap-band assertions | `src/game/ai/AiField.tsx:130-289`, `src/game/ai/raceSim.ts`, `raceSim.test.ts:68-116` (homogeneous-pack lap bands vs `LAP_BAND` in `ai/config.ts:71-80`) |
| 8 selectable ships — **visual only** | `src/game/craft/craftCatalog.ts:1-5` ("Visual-only in this slice: handling stays shared"); selection persisted as `settings.craftFamily` (`src/App.tsx:180-182`); QA gate 5.5 confirms "shared handling and collider contract hold" (`docs/qa/QA_GATES.md`) |
| Ship-select already in the online entry flow | `src/App.tsx:163-198`: Play → mode → ShipSelect → (`timeTrial`→TrackSelect \| `race`/`online`→launch) |

### 1.2 Discrepancies vs. the task brief (matters for scoping)

1. **AI item use is NOT landed.** `src/game/ai/index.ts:3`: "No weapon/item use in this slice." The driver hard-codes `fireWeapon: false, useUtility: false` (`src/game/ai/driver.ts:361-362`). The live `AiField` never touches inventory/combat stores.
2. **Balance instrumentation is NOT landed** as a distinct capability. What exists: telemetry ring buffer (`src/game/telemetry/ringBuffer.ts`), raceSim tier bands (Neon), weapon caps unit tests (`weapons.test.ts`), combat determinism replay (`combatReplay.test.ts:162-196`). There is no balance dashboard/aggregation module and no Foundry raceSim coverage.
3. **The 8-bot suite covers Neon only.** `raceSim.test.ts` imports only `neonOrbitalArtifact`; Foundry has just a 3-lap line-bot smoke (`src/game/bot/lineBot.test.ts:28-45`). The stated P3 exit gate ("both AI tracks × 8 bots pass balance/fairness suites") is therefore **not currently satisfiable** — §7.3 turns this into a concrete pre-P4 PR.
4. **Online mode today has no energy, items, or combat at all.** The whole P2.x stack is gated behind `soloLiteralRespawn = adapter?.mode !== "online"` in `src/game/craft/PlayerCraft.tsx:356-362` and the giant `if (soloLiteralRespawn) { ... }` block `:422-607`. P4 is not "sync combat", it is "bring combat online for the first time".

### 1.3 Latent bugs found during the audit (P4 must fix; also evidence for design choices)

- **Server speed cap is below the client boost envelope.** Module rejects `speed > MAX_SPEED_MS = 80` (`module/src/rules.ts:13`, enforced `module/src/index.ts:506-507` "Velocity exceeds 80 m/s"), but P1.4 tuning reaches `TERMINAL_BOOST = 88` and `SAFETY_SPEED_CAP = 105` (`src/game/craft/tuning.ts:146,152`). N0 predates the P1.4 envelope (commit #2 vs #6). Consequence today: boosting online produces publish rejections every 66 ms window the craft exceeds 80 m/s. Design consequence: **server caps must be generated from `craft/tuning.ts`, not hand-typed** (§3.1).
- **`reportCheckpointCrossed` hardcodes 8 gates.** `src/net/raceBridge.ts:5` throws for `n > 7`; Black Rain Foundry has 10 checkpoints. Any online Foundry work trips this immediately.
- **Client database name is hardcoded** to `"kzero"` (`src/net/spacetime.ts:74`) while the deployed maincloud DB in `spacetime.local.json` is `module-vc9m4`. P4 needs `VITE_STDB_DB` (or module rename) as part of M1.
- **Nothing gates driving during countdown.** No countdown check exists in craft input or `PlayerCraft` (verified by grep across `src/game/craft/`), and `publish_transform` accepts countdown-phase movement (`module/src/index.ts:501-503`). A client can creep off the grid before "GO". §6 adds a server grid-radius clamp during countdown.

---

## 2. Netcode model decision

### 2.1 Constraints the codebase imposes

1. **The craft sim cannot leave the client.** `craftController`/`craftPhysics` run against a live Rapier world (raycast suspension pads, hull-vs-track-slab collisions — `CLAUDE.md` "Surface is a solid slab" sharp edge; `PlayerCraft.tsx:364-374` `prepareCraftPhysicsStep({body, rapier, world, ...})`). SpacetimeDB modules are WASM sandboxes whose reducers must be deterministic with no I/O (`module/CLAUDE.md`, Critical Rules 1–2); there is no path to running `@dimforge/rapier3d-compat` (a WASM blob, `package.json:39`) inside a module. A server-authoritative craft sim means rewriting suspension + track collision in pure TS inside reducers — out of scope for v1 and re-opens the P1 fall-through class of bugs the slab collider closed.
2. **Determinism scope is same-build local replay only** — stated in `CLAUDE.md` (P1 section) and reflected in what's tested: golden hash across a same-process 600-tick replay (`compiler.test.ts`), same-process raceSim hash equality (`raceSim.test.ts:38-53`). Nothing validates cross-browser or cross-machine bit-equality of the Rapier WASM step, R3F mount order, or catch-up clamp behavior (`GameRuntime.ts advance()` clamps at 5 steps/100 ms — `constants.ts:7-8` — which under lockstep would desync the slow client instead of stalling it).
3. **The transport is a database, not a socket.** All client→server writes are reducer calls; all server→client data is row subscription (`module/CLAUDE.md`). There is no unreliable/unordered channel to tune; per-message overhead and commit latency are what they are. The N0 code already found the sensible operating point: 15 Hz pose publishes + interpolation ~120 ms behind (`transformSync.ts:77,162`).
4. **The feel package is the product.** P1.2/P1.4 invested heavily in zero-latency local control (drag-owned envelope, PD alignment, race-paced camera). Any model that inserts network delay between stick and craft regresses the core product promise.
5. **Combat math is already network-shaped.** `combatWorld.ts` is pure, Rapier-free, keyed by integer target ids with poses injected from outside (`upsertTarget`, `PlayerCraft.tsx:451-455`). It can therefore run (a) client-side against interpolated remote poses, and (b) partially server-side as pure geometry in reducers — both are used in §5.

### 2.2 Options considered

**(A) Full authoritative server (server simulates physics, clients send inputs, render server state).**
Rejected. Blocked outright by constraint 1. Even ignoring physics, a 60 Hz server tick per match implemented as a SpacetimeDB scheduled reducer writing 8 transform rows would generate ~480 row-writes/s of subscription fan-out per match and put every steering correction a full RTT away (constraint 4). No component of the existing runtime is reusable server-side except the pure rules.

**(B) Deterministic lockstep (relay quantized intents; every client simulates every craft).**
Attractive on paper because `QuantizedIntent` is 11 small fields (≈ 8 bytes packed; 60 Hz × 8 racers ≈ 4 KB/s — trivial), and the ring buffer/golden-hash machinery exists. Rejected for v1 on four grounds:
1. Cross-client determinism is unproven and out of contract (constraint 2). One divergent `Math.fround` path or mount-order difference desyncs the race silently; detection (hash exchange) exists, but recovery (full state resync of a Rapier world) does not.
2. Input delay: classic lockstep needs input scheduled ≥ RTT ahead; through a reducer+subscription round trip that is realistically 60–150 ms added stick latency — a direct hit on constraint 4.
3. Stall coupling: the sim cannot advance past a missing intent, so one tab-throttled or lossy peer freezes all eight (the catch-up clamp in `GameRuntime.advance` makes this worse, constraint 2).
4. Every remote craft would need its Rapier body driven by remote intents — that's 8 full craft sims per client (the solo Race mode already does 8, so CPU is fine) but ANY divergence compounds physically through hull-vs-hull collisions.

**(C) Rollback/prediction (GGPO-style: predict remote inputs, resimulate on correction).**
Fixes lockstep's latency/stall problems, inherits its determinism problem, and adds the hardest requirement: save/restore of full sim state (Rapier world snapshot + energy/items/combat stores) plus up-to-N-tick resimulation per render frame. Rapier supports world snapshotting, but snapshot+restore+resim of an 8-craft world at 60 Hz in a browser is a multi-week engineering and perf project with new failure modes (visual teleports on correction). Not proportionate to a friends-lobby browser racer; noted as the future path if K-ZERO ever needs competitive integrity for driving itself.

**(D) Validated client authority for continuous state + server authority for discrete state (extend N0).**
Each client is authoritative over its own craft's pose (validated by caps), the server is authoritative over everything that can be disputed: phase, laps, pickups, inventory, damage, kills, respawns, results. Combat feedback is immediate locally; combat *outcomes* settle server-side within ~1 RTT. This is exactly the shape N0 already built and tested (movement caps, respawn tokens, checkpoint monotonicity — `module/src/rules.ts:374-503`), and it's the standard model for casual/mid-core online racers.

### 2.3 Recommendation

**Option D.** Rationale in one line each:
- It is the only option compatible with all five constraints simultaneously.
- It reuses ~everything: the module's validated relay and lifecycle, the client interpolation buffer, the pure combat world, the pure rules test harness.
- Its known weaknesses (a hacked client can drive impossibly *well* but not impossibly *fast*; hit disputes at high RTT) are bounded by server caps and are acceptable at the trust level of an 8-player lobby game (§6 states the explicit trust model).
- It leaves a clean upgrade path: because all discrete outcomes already settle server-side, a later rollback-driving upgrade (option C) would change only the pose channel.

Remote craft remain **non-colliding interpolated ghosts in v1** (exactly N0's `GhostCrafts`, `src/game/GhostCraft.tsx:7` `MAX_ONLINE_GHOSTS = 7`), upgraded from instanced boxes to per-ship far-LOD meshes (§4.4). Local-only kinematic collision hulls for remote craft are a flagged, QA-gated stretch milestone (M7): each client would collide against remote hulls positioned at interpolated poses; the response is asymmetric (only you feel the bounce) but bounded by the server movement caps. It ships only if piloted QA says the asymmetry reads acceptably; racing lines and combat do not depend on it.

---

## 3. SpacetimeDB schema and reducers

Design rules applied throughout: (i) reducers stay thin and validate against generated constants, mirroring the N0 pure-rules pattern so everything is testable without the CLI; (ii) no always-on scheduled reducers — schedules exist only at edges (countdown end, rail resolve, respawn due, fatal-boost zero-crossing, DNF grace, janitor), because maincloud bills per reducer execution; (iii) continuous quantities (energy) are settled lazily inside reducers that already fire (chiefly `publish_transform` at 15 Hz), never on a server tick.

### 3.1 Generated data expansion (prerequisite codegen work)

The single-artifact rule (`CLAUDE.md` P1.3) extends to the server:

- **`module/src/trackData.generated.ts` v2** — emitted by `pnpm track:build` for **every** REGISTRY entry, not just Neon (`cli.ts:28-41` currently writes only Neon's `moduleDataPath`). Per track: `trackId`, `trackVersion`, `compilerVersion`, `gameplayHash`, `checkpointCount`, `gridPoses[8]`, `pickupSockets[] {rowId, family, pos, half}` (from `TrackArtifact.pickupSockets`, `artifactTypes.ts:239-243`), `rechargeStrips[] {pos, quat, half}`, `respawnPoses[]` (for server fall-token minting per track), and a derived `minCheckpointSplitUs` per gate pair (replacing the hand constant `MIN_CHECKPOINT_SPLIT_US = 3 s`, `module/src/rules.ts:17`, which is Neon-tuned; derive as a safety fraction of elite AI sector times from `aiSpeed`).
- **`module/src/combatTuning.generated.ts`** — new script (`pnpm combat:gen`, wired into `pnpm track:check`-style drift guard) emitting from `src/game/weapons/weaponTuning.ts` + `energy/energyTuning.ts` + `craft/tuning.ts`: per-family damage values/caps, immunity window (120 ms) in µs, stun/slow caps in µs, utility parameters (Aegis 280/8 s, Specter 1.25 s, Overdrive +120/0.9 s, Nanite 220/2.5 s/1 s pause), energy constants (1000/120 s⁻¹/320 s⁻¹/+250/500), respawn timing (1 s, ghost 0.25 s, grace 1 s), and the **speed caps** `TERMINAL_BOOST`/`SAFETY_SPEED_CAP` that replace `MAX_SPEED_MS = 80` (fixes the §1.3 drift class permanently: publish validation cap becomes `SAFETY_SPEED_CAP × margin`).
- Rationale for generation over import: the module builds standalone from `module/` with its own `package.json`/`node_modules` (`module/package.json`), so it cannot import `src/game/...`; the generated-file pattern is already the established precedent (`codegen.ts` header "GENERATED by `pnpm track:build`").

### 3.2 Tables

Types per the TS server SDK in `module/CLAUDE.md`. `identity` stays the PK for participant/transform/combat rows — one active match per identity, which also makes the N0 authority checks (`row.authority.isEqual(ctx.sender)`, `module/src/index.ts:495`) carry over unchanged. `match_id` columns get btree indexes.

| Table | Columns (abridged) | Notes |
|---|---|---|
| `server_info` (public) | `id u8 PK`, `protocol_version u32`, `min_client_protocol u32` | Lets the client distinguish "module too old/new" from "track hash mismatch"; seeded in `init` |
| `track` (public) | `track_id string PK`, `compiler_version u32`, `track_version u32`, `gameplay_hash u32`, `checkpoint_count u8`, `grid_slot_count u8` | Seeded from trackData v2 in `init`; re-seeded (upsert) on publish migration |
| `track_grid_pose` | `id u64 PK autoInc`, `track_id (btree)`, `slot u8`, `px..pz f32`, `rx..rw f32` | Child table; also `track_respawn_pose`, `track_recharge_strip`, `track_pickup_socket` with the same shape pattern (socket adds `socket_index u16`, `row_id u16`, `family u8`, `half_* f32`) |
| `match` (public) | `id u64 PK autoInc`, `code string unique`, `status string` (`lobby\|countdown\|racing\|finished`), `track_id string`, `compiler_version u32`, `gameplay_hash u32`, `track_version u32`, `lap_count u8 = 3`, `seed u64`, `max_players u8 = 8`, `countdown_ends_at/started_at/finished_at option<timestamp>`, `host_identity option<identity>`, `results_lock_until option<timestamp>`, `created_at timestamp` | The three contract fields are **frozen copies** taken from `track` at creation (handshake anchor, §3.4). `seed` drives pickup rolls |
| `participant` (public) | as N0 (`module/src/index.ts:47-66`) + `match_id u64 (btree)`, `craft_family string`, `kills u8`, `deaths u8` | identity PK preserved |
| `transform` (public) | as N0 (`:68-83`) + `match_id u64 (btree)`, `boosting bool` | `boosting` feeds server energy settlement (§3.3) and remote exhaust VFX |
| `combat_state` (public) | `identity PK`, `match_id (btree)`, `energy i32`, `energy_updated_at timestamp`, `status string` (`alive\|destroyed`), `destroyed_at/respawn_due_at option<timestamp>`, `ghost_until/grace_until option<timestamp>`, `weapon_slot option<string>`, `utility_slot option<string>`, `shield_hp i32`, `shield_until option<timestamp>`, `specter_until option<timestamp>`, `specter_decoy_x/y/z f32`, `overdrive_until option<timestamp>`, `nanite_remaining i32`, `nanite_until/nanite_paused_until option<timestamp>`, `utility_disabled_until option<timestamp>`, `stun_until option<timestamp>`, `slow_until option<timestamp>`, `slow_fraction_q u8`, `imm_pulse/imm_arc/imm_mine/imm_seeker/imm_rail/imm_emp option<timestamp>` | One row per racer; the server-side twin of `CombatTarget` (`combatWorld.ts:111-120`) with times in server clock instead of ticks. Wide-but-flat beats child tables at this scale (≤ 8 rows/match) |
| `pickup_state` (public) | `id u64 PK autoInc`, `match_id (btree)`, `socket_index u16`, `respawn_at option<timestamp>`, `claim_seq u16` | Pose/family live in `track_pickup_socket`; this row is only availability. Client renders pads from its artifact + this row |
| `mine_entity` (public) | `id u64 PK autoInc`, `match_id (btree)`, `owner identity`, `px/py/pz f32`, `armed_at timestamp`, `expire_at timestamp` | Server registry for victim-side triggers (§5); public so all clients render remote mines authoritatively |
| `rail_charge` | `id u64 PK autoInc`, `match_id`, `owner identity`, `px..pz`, `fx..fz f32`, `resolve_at timestamp` | Private is fine (clients render the telegraph from the fire event); resolved by scheduled reducer |
| `combat_event` (public, `event: true`) | `match_id`, `kind string` (`fire\|hit\|utility\|kill\|respawn\|deny`), `attacker identity`, `victim option<identity>`, `weapon string`, `family string`, `damage i32`, `shield_absorbed i32`, `px..pz`, `dx..dz f32`, `server_time timestamp` | Event table (`module/CLAUDE.md`, Event Tables): broadcast-only, never cached client-side — the VFX/telegraph fan-out channel. Persistence semantics to verify in the M1 spike (§10 Q3) |
| Scheduled tables | `start_race_schedule`, `finish_timeout_schedule`, `dnf_schedule` (as N0, + `match_id`), plus new `respawn_schedule {target, match_id}`, `rail_resolve_schedule {charge_id}`, `energy_zero_schedule {target}`, `janitor_schedule` | All one-shot except the janitor (long interval, e.g. 60 s, deleting abandoned lobby matches / finished matches older than N minutes) |

Deleted relative to N0: the singleton `race` row seeded in `init` (`module/src/index.ts:280-292`); `init` now seeds `server_info` + `track` rows only.

### 3.3 Reducers

Carry-overs keep their N0 validation logic, re-scoped to the caller's match (resolved via `participant.identity.find(ctx.sender).match_id`).

**Lifecycle / rooms**
- `create_match {track_id}` — track must exist; copies `{compiler_version, gameplay_hash, track_version}` from `track` onto the row; mints `code` (5 chars from `ctx.random`, `module/CLAUDE.md` Reducer Context); creator joins in the same transaction (grid slot 0).
- `join_match {code | match_id, name, color, craft_family, compiler_version, gameplay_hash}` — **the handshake gate** (§3.4). Also validates: lobby status, name 1–24 (as N0 `:343`), `craft_family` ∈ the 8 catalog ids (mirrored into combatTuning.generated), free grid slot, sender not already in a match.
- `leave_match` — explicit leave (N0 only handled disconnect); lobby: delete rows; racing: DNF-equivalent.
- `set_ready {ready}`, `set_ship {craft_family}`, `set_track {track_id}` (host-only, lobby-only; re-freezes the contract triple from `track`) — ready-all → countdown + grid respawn-token mint, exactly N0 `set_ready:395-415`.
- `start_race` (scheduled), `finish_timeout` (scheduled), `apply_dnf` (scheduled), `request_rematch`, connect/disconnect hooks — N0 semantics per match (`:419-468`, `:667-683`, `:703-709`, `:644-665`, `:294-335`, `:730-795`), including the 15 s reconnect-grace ghost flow.
- `janitor` (scheduled, repeating) — deletes matches with zero online participants (lobby immediately; others after grace) and their child rows.

**Driving**
- `publish_transform {…N0 args, boosting}` — N0 validation chain (`module/src/rules.ts:374-442`: authority, ghosted/DNF, phase, finite, speed cap, distance-vs-server-elapsed cap, respawn-token path) with three changes: (1) speed cap from generated `SAFETY_SPEED_CAP × 1.05` instead of 80; (2) **energy settlement**: integrate `combat_state.energy` from `energy_updated_at` to now using generated rates — boost drain if `boosting` (and not overdrive-free), strip recharge if the published pose is inside a `track_recharge_strip` OBB, nanite repair if active — then update `energy_updated_at`; if energy hits 0 with `boosting`, execute the fatal-boost destroy path (§5.5); (3) countdown grid clamp (§6).
- `cross_checkpoint {n}` — N0 monotonic/idempotent logic (`rules.ts:449-503`) with `checkpoint_count` and min-split from the match's track row instead of constants; finish → `finish_ms`, `maybeFinishRace`.
- `request_fall_respawn` — N0 token mint at lifted last pose (`rules.ts:510-526`), reused verbatim; P4 adds the combat-death token path (§5.5).
- `set_boost {active}` — edge fallback so drain doesn't wait for the next 15 Hz publish when HUD-critical (schedules/cancels `energy_zero_schedule` at the projected zero-crossing). Optional if publish-settlement proves tight enough in the latency harness; keep in the plan, cut in M3 if redundant.

**Items / combat** (full designs in §5)
- `claim_pickup {socket_index}`
- `fire_weapon {weapon_id, px..pz, dx..dz, client_tick}`
- `claim_hit {victim, family, projectile_seq, px..pz}`
- `trigger_mine {mine_id}`
- `use_utility {utility_id, px..pz, dx..dz}`
- `resolve_rail` (scheduled), `apply_respawn` (scheduled), `energy_zero_check` (scheduled)

**Pure-rules mirror.** Every reducer above gets a reducer-equivalent pure function in `module/src/rules.ts` (or a new `module/src/matchRules.ts` if the file gets unwieldy) operating on an extended `MatchDb`, preserving the N0 test pattern (`rules.ts:225` "Reducer-equivalent pure operations (throw on invalid)"). This is what the latency harness (§8.2) executes.

### 3.4 The GAMEPLAY_HASH handshake, end to end (hard constraint)

Truth chain:
1. `pnpm track:build` compiles each `TrackDefinition` → `TrackArtifact` whose `contract` carries `{compilerVersion, trackId, trackVersion, gameplayHash, artVersion}` (`artifactTypes.ts:201-209`); the same run emits trackData v2 into `module/src/` (§3.1). Client bundle and module are therefore built from the **same generated numbers** — the existing single-artifact rule extended to two tracks.
2. Module `init`/publish seeds `track` rows from trackData v2.
3. `create_match`/`set_track` freeze `{compiler_version, gameplay_hash, track_version}` from `track` onto the `match` row. Freezing matters: a module republish mid-lifecycle must not mutate a live match's contract.
4. `join_match` requires the client to present `{compiler_version, gameplay_hash}` read from **its own bundled artifact** for the match's `track_id` (`TRACK_CATALOG[key].artifact.contract`, `src/game/track/catalog.ts:34-55`). Server compares against the match row; on mismatch throws a structured error string, e.g. `INCOMPATIBLE_VERSION:{server_hash}:{client_hash}` (reducers can only signal via thrown errors — `module/CLAUDE.md` Critical Rule 1 — so the client parses the prefix).
5. Client pre-checks before even calling: it subscribes to `track` + `match`, compares locally, and renders the **`incompatible-version`** UI state without a doomed reducer call; the server check remains the enforcement (belt and braces — a stale client by definition can't be trusted to pre-check).
6. `publish_transform`/`cross_checkpoint`/combat reducers do **not** re-verify the hash per call — membership implies a passed handshake; rows are keyed by identity and participants can't switch matches without re-joining.

Client UX for `incompatible-version` (new state in the online shell, §4.1): full-screen card "Incompatible game version — this lobby runs track data `v{trackVersion}/{hash}` but your build has `v…/…`. Refresh to update." plus a Back action. Both directions (client older / server older) land here; `server_info.protocol_version` distinguishes "module API too old/new" with the same screen and different copy.

Deploy runbook consequence: module publish and Vercel deploy should come from the same commit; order doesn't matter for safety (mismatch joins are rejected cleanly either way), but module-first minimizes the incompatibility window since Vercel serves the previous client until the new build finishes.

### 3.5 Subscriptions and bandwidth budget

Client subscribes (parameterized by its match id after join; `spacetime.ts:86-91` currently subscribes to whole tables — P4 scopes with SQL `WHERE match_id = …`):
`server_info`, `track` (+ child tables once at boot), `match WHERE status='lobby'` (browser) or `WHERE id={mine}` (in match), `participant/transform/combat_state/pickup_state/mine_entity WHERE match_id={mine}`, `combat_event WHERE match_id={mine}`.

Budget at 8 players: transforms 8 × 15 Hz ≈ 120 row-updates/s fan-out per subscriber (~15–20 KB/s at ~130 B/row wire size) — the same order as N0 today, which is proven fine. `combat_state` writes are event-driven (hits/pickups/utilities), not periodic; energy settlement piggybacks on transform writes (same transaction, so one subscription delta). Pickup/mine/event rows are sparse. No new sustained channels are added — the design deliberately keeps *continuous* state at 15 Hz and everything else edge-triggered.

---

## 4. Matchmaking, rooms, lobby, ship select, race lifecycle

### 4.1 Client shell flow (extends `src/App.tsx`)

Current online path: Play → ModeSelect(`online`) → ShipSelect → `applyOnline()` which forces Neon and mounts `<Lobby/>` over the scene (`App.tsx:147-161, 326`). P4 replaces `applyOnline` with an **online shell state machine** (new `src/net/onlineShell.ts` store + `src/hud/MatchBrowser.tsx`, keeping `Lobby.tsx` as the in-match panel):

`modeSelect → shipSelect → matchBrowser → lobby(match) → playing(trackKey from match.track_id) → results → (rematch → lobby | leave → matchBrowser)`
plus terminal states `incompatible-version` (§3.4) and `disconnected` (auto-retry with backoff; SpacetimeDB SDK reconnect resumes the identity token already persisted at `spacetime.ts:75`).

- **MatchBrowser:** list from `match WHERE status='lobby'` (name = host + track + player count), Create (track picker: Neon/Foundry from `TRACK_CATALOG`), Join-by-code input, Quick Match (join first non-full lobby else create Neon). Private lobbies are just "don't advertise": a `listed bool` on match, filter in the subscription.
- **Track loading on join:** `match.track_id` → `TrackKey` (inverse of `catalog.ts:74-85` `resolveTrackKeyFromSearch` id mapping) → `setActiveTrackKey` + `<Scene trackKey/>` remount. This kills the "online is always Neon" hardcode (`App.tsx:148-149`, `matchMode.ts:41-50` — whose comment already promises exactly this change).
- **Ship select integration:** `craft_family` is sent in `join_match` and changeable in lobby via `set_ship` until ready. The lobby roster shows each pilot's ship name/accent (`CRAFT_CATALOG` fields, `craftCatalog.ts:33-43`). Because ships are visual-only (§1.1), no server validation beyond id membership is needed — explicitly no per-ship stats reach the server, and the plan keeps it that way for v1.

### 4.2 Race lifecycle (server states, N0-proven, per match)

`lobby` (join/ready/ship/track) → all-connected-ready ∧ ≥ 2 → `countdown` (3 s, `COUNTDOWN_US`, grid respawn tokens minted — N0 `set_ready:403-414`) → `start_race` (scheduled; aborts back to lobby if < 2 connected — `:426-436`) → `racing` (transform relay + checkpoints + combat; 300 s finish timeout — `rules.ts:24`) → `finished` (host election, 3 s results lock, rematch — `:644-665`). DNF: disconnect during racing ghosts the participant for 15 s grace, then scheduled DNF (`onDisconnect:769-789`); reconnect inside grace restores with a respawn token at the last pose (`onConnect:303-325`). All of this exists and is tested; P4 re-scopes it per match and adds `kills/deaths` to the results payload.

**Countdown display sync:** the client compares server `countdown_ends_at` to `Date.now()` (`matchAdapter.ts:78-83`); clock skew shifts the displayed count but not fairness (racing starts server-side). P4 adds a rough server-clock offset estimate in `spacetime.ts` (EWMA of `row.updated_at` vs local receipt time on transform rows) used for countdown and telegraph timers; ±100 ms accuracy is sufficient.

### 4.3 Disconnect / rejoin during combat

Beyond N0: on ghost (disconnect), the server clears transient combat targeting — live seekers shooter-side simply lose the target when the ghost flag propagates (mirrors `combatWorld.ts:1259-1263` target-death handling); `combat_state` persists energy/slots through the grace window so a rejoin restores inventory and energy; if DNF finalizes, the participant's mines expire (delete `mine_entity WHERE owner`) and slots clear.

### 4.4 Remote ghost rendering

Replace the instanced-box `GhostCrafts` with per-participant `CraftVisualMesh family={participant.craft_family} farOnly` (the exact budget-safe variant AiCraft uses — `PlayerCraft.tsx:1137`), positioned by the existing `interpolateGhost` buffer, with name tags and `boosting` exhaust. Cap stays 7 (`GhostCraft.tsx:7`), within the Tier-A budget already proven by the 8-craft solo Race mode.

---

## 5. Combat and weapons under latency

### 5.1 Architecture: three resolution classes

The local `CombatWorld` keeps running on every client at 60 Hz, but online it is **split by ownership**:
- **Local-owned munitions** (you fired them): simulated locally against remote targets whose poses are the interpolated ghosts, upserted per tick via `upsertTarget` with `id = grid_slot + 1000·remote` mapping (new `src/net/combatNetBridge.ts`). Your hits on remote targets become *claims* or are already server-resolved depending on weapon class (below). Your local world does **not** apply damage to remote targets' authoritative energy — it renders predicted impact VFX only; authoritative damage arrives back as `combat_event` rows.
- **Remote-owned munitions** (fired at you): rendered from `fire` events as visual-only entities in a lightweight VFX list (not in the hit-applying combat world, avoiding double application). For seekers targeting *you*, the local visual homes using your true local pose — which is *more* accurate than the shooter's view and drives honest threat telegraphs (`CombatFeedback` lock warnings) with only ~½ RTT of lag.
- **Authoritative outcomes**: all damage, shield absorb, control-loss, kills, refunds, and respawns are computed server-side in reducers against `combat_state` and broadcast as `hit`/`kill` events + row updates. The victim's client applies stun/slow to its own craft when its `combat_state.stun_until/slow_until` updates arrive (the craft adapter already has the hook: `applyControlLossToInput` — `PlayerCraft.tsx:834-847`).

### 5.2 Per-weapon reconciliation

| Weapon | Fire-time server action (`fire_weapon`) | Hit resolution | Latency reasoning |
|---|---|---|---|
| **Pulse** (3 bolts, 130 m/s, 70 dmg/bolt, life 1.6 s — `weaponTuning.ts:73-94`) | Validate slot+pose, clear slot, emit `fire` event | **Shooter claim** per bolt (`claim_hit {victim, family:'pulse', projectile_seq: 0-2}`). Server checks: bolt count ≤ 3 per fire event, victim distance from fire origin ≤ 130·elapsed + tolerance, victim alive/not-graced, per-family immunity, fixed 70 dmg | Travel-time weapon aimed at where the shooter *sees* the target (~120 ms past). Server-side re-simulation against fresher rows would systematically deny legitimate hits; shooter-favored claims with plausibility caps is the standard resolution. Tolerance = `SAFETY_SPEED_CAP × (staleness + 2·publish interval)` |
| **Arc** (instant cone 45 m/22°, 120–220 dmg — `:98-114`) | Validate, clear slot, **resolve hits server-side immediately**: pure cone/corridor test (port of `fireArc` geometry, `combatWorld.ts:673-727`) against victim transform rows extrapolated by `vel × staleness`; apply damage per-victim; emit `fire` + `hit` events | Server-instant | Instant + wide + short-range: the geometry test on ≤ 66 ms-stale rows with velocity extrapolation misjudges by ≤ ~1–2 m at closing speeds — inside the 6 m corridor half-width. No claim path = no cheating surface on the roster's spammiest damage |
| **Mine** (arm 0.45 s, core 2 m, 190 dmg, pull 7 m, life 12 s — `:118-142`) | Validate; insert `mine_entity` row (pos snapped rear of shooter); emit event | **Victim-triggered**: each client tests its *own* true pose against subscribed armed mines per tick (client-side, exact); on entry calls `trigger_mine {mine_id}`; server validates victim pose (its transform row) within `coreRadius + tolerance` of the mine, armed, not expired → damage+slow, delete mine. Pull-field slow applies locally as a client-side control effect and is *also* server-set (slow fields on trigger only, v1 simplification: pull slow applies on core trigger; the cosmetic pull inside 7 m stays client-side feel) | The victim's own pose is the one continuous quantity that client is *already* authoritative over — so mine hits are exact for the person they matter to, immune to shooter latency, and un-spoofable beyond the existing movement caps. Matches the offline semantics (mine vs pose distance test, `combatWorld.ts:1504-1522`) |
| **Seeker** (95 m/s homing, 260 dmg, lock 180 m/55°, life 4.5 s — `:146-167`) | Validate; server computes initial lock target with the pure `findSeekerLockTarget` cone logic against rows (respecting `specter_until`); event carries `targetId` | **Shooter claim** on impact (shooter's local homing sim vs interpolated target). Server validates: victim == locked target (or null-lock dumbfire proximity), elapsed ≥ min flight time for the distance, ≤ life, specter window check **at server clock** (claims inside `specter_until` are denied), immunity, fixed 260 dmg | Homing forgives interpolation error (turn rate 28°/s chases the ghost). The counterplay race — "Specter popped while seeker in flight" — resolves server-side: whoever's reducer commits first wins, and a specter commit strictly before the hit claim always spoofs it. Shooter may see a phantom impact that dealt no damage (event `deny`); acceptable, and the victim (who the fairness matters to) sees their countermeasure respected |
| **Rail** (0.65 s charge, corridor 110 m × r1.1, 340/170 — `:171-186`) | Validate; insert `rail_charge {pose, dir, resolve_at = now + 0.65 s}`; emit `fire` (charge telegraph) | **Server-scheduled resolve** at `resolve_at`: corridor test against transform rows (port of `resolveRailCharge`, `combatWorld.ts:878-924`), first/second penetrator damage; emits `hit` events | The 650 ms telegraph ≫ RTT: victims see the charge beam warning (locally rendered from the fire event ~½ RTT after fire) with ≥ 400 ms to dodge even at 200 ms RTT. Server resolve at a fixed future time makes the corridor identical for everyone and removes shooter-side abuse of the roster's biggest single hit |
| **EMP-Quake** (instant wave 120 m × 14 m, 180 dmg + 0.45 s stun + 1 s utility disable, clears munitions — `:190-206`) | Validate; **server-instant**: wave volume test vs rows (port of `fireEmp`, `combatWorld.ts:926-998`); damage + `stun_until` + `utility_disabled_until` on victims; delete foreign `mine_entity`/`rail_charge` rows in volume; emit events (clients also clear their local/visual munitions in the volume — including in-flight pulse/seekers, which are client-side entities cleared on event receipt) | Same reasoning as Arc; the utility-disable and munition-clear must be authoritative to be fair, and rows make that a pure server operation |

Damage numbers are never client-supplied — `claim_hit` carries no damage field; the server looks up generated constants (Arc's range-blend damage is computed server-side from its own geometry). "No one-shot from full energy" (`MAX_DAMAGE_FROM_FULL`, `weaponTuning.ts:65-69`) and per-family 120 ms immunity are enforced in the server hit application, mirroring `applyHit` (`combatWorld.ts:1013-1160`): shield absorb first → damage → immunity mark → control-loss caps → nanite pause → kill detection → refund.

### 5.3 Utilities and counterplay windows

`use_utility {utility_id}` validates the slot and `utility_disabled_until`, then writes server state: Aegis → `shield_hp = 280, shield_until = +8 s`; Specter → `specter_until = +1.25 s` + decoy pos (spoof handled at claim/lock validation, above); Overdrive → `energy += 120` (cap 1000) + `overdrive_until = +0.9 s` (publish settlement treats boost as free inside the window); Nanite → `nanite_remaining = 220, nanite_until = +2.5 s` (settled lazily in publish settlement; `nanite_paused_until = +1 s` set by server hit application; the offline "no grant while boosting" rule from `CLAUDE.md` P2.5 carries into the settlement formula). The activating client also applies the effect optimistically to its local combat world for instant HUD/VFX; server state reconciles within a round trip. Telegraph durations that gate counterplay (seeker lock warn, rail charge 0.65 s, mine arm 0.45 s, EMP disable 1 s) all exceed realistic RTT by 3–10×, which is the structural reason this roster tolerates latency well.

### 5.4 Item pickups

Server-arbitrated, first commit wins: `claim_pickup {socket_index}` validates racing+alive, socket available (`pickup_state`), claimant transform within `PICKUP_CLAIM_HALF`-derived OBB + staleness tolerance of the socket pose (`track_pickup_socket`), then rolls via the pure roll tables (`rollTables.ts` ports to generated data; roll inputs: family legality → **server-truth gap-to-leader seconds** (computed from participant lap/next_checkpoint + transform arc positions — the exact seam `roll.ts:29-30` reserved) → rarity), writes the won item into `weapon_slot`/`utility_slot`, sets `respawn_at = +5 s` (per-socket, matching `PICKUP_RESPAWN_TICKS` semantics, `pickups.ts:1-8`). Roll determinism/auditability: seed = `match.seed ⊕ socket_index ⊕ claim_seq` so post-race audit can re-derive every roll. Two racers claiming the same pad within one round trip: second reducer sees `respawn_at` set and throws; the loser's client clears its optimistic pad-darken on the row update. Absorb (hold-to-absorb 0.6 s for `absorbEnergy`) stays fully client-side for feel but the energy grant routes through a tiny `absorb_item` reducer (server clears the slot and credits generated `absorbEnergy` — otherwise inventory desyncs).

### 5.5 Death and respawn online (replaces the solo literal-pose path)

Server detects `energy ≤ 0` in hit application or fatal-boost settlement → `combat_state.status='destroyed'`, `deaths+1`, attacker `kills+1` + `KILL_REFUND` energy, emit `kill` event, schedule `apply_respawn` at `+1 s` (`RESPAWN_DELAY_TICKS`-equivalent in µs). `apply_respawn` mints the N0 respawn token **at the captured death pose** (reusing `mintRespawn`, `module/src/index.ts:163-178`) with `energy = 500`, `ghost_until = +0.25 s`, `grace_until = +1 s`; the client's existing token-teleport machinery (`transformSync.ts:21-33` `teleportServerRespawn`) executes the literal-pose revive, and the client plays the destroy burst/freeze presentation it already has (`PlayerCraft.tsx:620-650`), driven by `combat_state.status` instead of local energy. Void deaths: death pose below `FALL_Y_THRESHOLD` respawns via the nearest `track_respawn_pose` instead (server-side port of the `fallRecovery` selection), preserving the "void combat deaths hold literal pose through grace, then safe-frame" contract (`CLAUDE.md` P2.2) with a simpler server rule for v1. Server rejects hit claims and mine triggers against victims inside `grace_until`/`ghost_until`.

---

## 6. Anti-cheat basics (proportionate to a browser friends-lobby game)

**Trust model, stated plainly:** clients are authoritative over their own continuous motion inside server caps; we prevent *impossible* states and *unauthorized discrete outcomes*, not superhuman-but-legal play (aimbots, perfect lines). That matches the game's audience; anything stronger requires the rejected server-physics/rollback models.

Carried over from N0 (all already implemented and unit-tested in `module/src/rules.ts`): per-identity transform authority; finite-pose checks; speed cap (now generated, `SAFETY_SPEED_CAP × 1.05`); teleport cap via `maxMoveDistance(server-elapsed) × 1.25` margin (`rules.ts:125-129`); one-time server respawn tokens with pose-match epsilon (`:143-152, 413-436`); checkpoint monotonicity + idempotent dup + min split (`:449-503`, split becomes per-track generated); movement limits measured on server elapsed time, not publish cadence.

Added in P4:
1. **Server-owned inventory** — you cannot fire a weapon you didn't pick up; one fire per pickup (slot cleared in `fire_weapon`); pickups position-validated. This single property collapses most combat cheating.
2. **Server damage tables + caps** — no client-supplied damage; per-family immunity, stun/slow caps, no-one-shot, grace windows all server-side (§5.2).
3. **Countdown grid clamp** — during `countdown`, `publish_transform` rejects poses > ~3 m from the participant's grid pose (fixes the false-start hole, §1.3).
4. **Rate limits** — per-identity: publishes ≥ 40 ms apart (else drop-not-throw), `claim_hit` ≤ bolt count per fire event, `fire_weapon` requires non-empty slot (natural cap), `claim_pickup` ≤ 1 per 250 ms.
5. **Reject-counter telemetry** — `participant.reject_count` incremented on validation throws; ≥ N in a match → auto-DNF + host notification. Post-race plausibility: finish/lap times below an artifact-derived floor (elite AI lap × 0.85) flag the result row (`suspect bool`) rather than blocking (false positives are worse than a flagged leaderboard at this scale).
6. **Identity** — SpacetimeDB identity tokens persisted per browser (`spacetime.ts:75`); no accounts in v1. Kick/ban = host-side `kick_participant` reducer (host_identity check) that DNFs and blocks rejoin for the match. Sufficient for friends lobbies; anything global is out of scope.

Explicitly out of scope, documented for the captain: aim assistance detection, input-pattern analysis, client integrity attestation, replay-based adjudication, per-account reputation.

---

## 7. Migration from the current single-player runtime

### 7.1 What stays untouched

- The fixed-tick runtime, system order, input path, and all solo modes (`GameRuntime`, `FixedStepDriver`, `SYSTEM_ORDER` bands `constants.ts:11-21`).
- The craft controller/physics, suspension, speed envelope, handling verbs — the local sim is the product; online changes only *who arbitrates outcomes*.
- The whole pure combat/energy/items math (`combatWorld`, `energy.ts`, `pickups.ts`, `roll.ts`) — reused client-side and partially ported (pure geometry) server-side.
- Track compiler, artifacts, catalog; solo track select; AI solo Race mode; feel package; audio; persistence.

### 7.2 What changes (client), file by file

| Area | Change |
|---|---|
| `src/net/spacetime.ts` | Env-driven `VITE_STDB_URI` + new `VITE_STDB_DB`; match-scoped subscriptions (§3.5); server-clock offset estimator; regenerated bindings for the v2 schema — `src/net/bindings/*` are checked-in output of `spacetime generate` (headers: "AUTOMATICALLY GENERATED BY SPACETIMEDB", CLI 2.6.1), so M1 needs a CLI-equipped environment for regeneration (`CLAUDE.md` notes the CLI is often absent in agent environments) |
| `src/net/matchAdapter.ts` | `SpacetimeMatchAdapter` gains match context (id, track, contract), pre-join handshake check, and combat/pickup reducer wrappers; keeps `syncRemotePhase` mirroring (`raceState.forceCountdown/forcePhase/mirrorProgress` already exist for exactly this) |
| `src/net/raceBridge.ts` | Kill the hardcoded `n > 7` (§1.3); gate count from match track row → `race.setGateCount` (API exists: `raceState.ts:143-149`, already called by `Track.tsx:386`) |
| `src/net/transformSync.ts` | Publish payload + `boosting`; unchanged cadence/interp; ghost buffer keyed by identity as today |
| **new** `src/net/combatNetBridge.ts` | The one genuinely new client module (§5.1): remote targets → local combat world upserts; local fire/claims → reducers; `combat_state`/events → local energy snap, control-loss application, VFX list for remote munitions, HUD threat feeds |
| `src/net/onlineShell.ts` + `src/hud/MatchBrowser.tsx` + `Lobby.tsx` rework | §4.1 flow incl. `incompatible-version` state; ship/track in lobby |
| `src/game/craft/PlayerCraft.tsx` | The surgical change: replace the boolean `soloLiteralRespawn` fork (`:356-362`) with a `MatchAuthority` strategy object — `solo` (today's literal-pose + local combat block) vs `online` (energy *predicted* locally but settled from `combat_state`; pickups/fire/utility routed through combatNetBridge; destroy/respawn driven by server rows/tokens; fall recovery → `request_fall_respawn` as N0 `RaceController.tsx:93-101` already does). Everything inside the fork already exists — the work is re-plumbing sources of truth, not new mechanics |
| `src/game/GhostCraft.tsx` | Per-ship far-LOD ghosts + boost exhaust + tags (§4.4) |
| `src/hud/*` | HUD reads the same local stores; add kills/deaths to results; `EnergyBar`/`ItemSlots`/`CombatFeedback` work unchanged because combatNetBridge feeds the same stores they subscribe to |
| `src/App.tsx` | Online no longer forces `DEFAULT_TRACK_KEY` (`:148-149`); shell states from onlineShell |

### 7.3 Schema-freeze checkpoint (the P3 exit gate, made concrete)

The module snapshots gameplay constants (damage tables, energy rates, caps, track hashes) at publish time, so every balance change after M1 becomes a client+module redeploy. Freeze discipline:

**Pre-M1 gate PR ("P3-exit"):** extend the 8-bot suites to *both* tracks — `raceSim.test.ts` gains Black Rain Foundry runs (completion/no-softlock/determinism/off-track bounds) and homogeneous-pack tier lap bands vs `LAP_BAND` on Foundry; keep Neon. Add a small balance-summary script (`scripts/balance-report.mjs`) that prints tier means, band margins, and weapon-cap check results for both tracks — this is the "balance instrumentation" the brief assumed and the artifact the captain signs off on. **Gate:** both tracks × 8 bots green in `pnpm test` + captain sign-off on the report ⇒ tuning constants are frozen; subsequent tuning changes during P4 require an explicit "unfreeze" note in the PR description and a regenerated `combatTuning.generated.ts`. (Honest caveat, per §1.2: with AI item use not landed, this gate exercises *racing* balance only; weapon balance freezes on the strength of the unit-test caps + offline QA rather than bot combat statistics. If the captain wants bot-combat balance evidence first, that is a P3 scope addition, not a P4 task — flagged as open question Q1.)

The freeze applies to: `weaponTuning.ts`, `energyTuning.ts`, `itemTuning.ts`/roll tables, `craft/tuning.ts` envelope, `trackVersion`s. `gameplayHash` changes (track edits) remain allowed but bump `trackVersion` per the existing contract and invalidate old clients by design — that's the handshake working as intended.

---

## 8. Testing strategy

Extends the existing registry (`scripts/test.mjs:25-54`) — all new suites run under plain `node --test` against `tsconfig.test.json` output like everything else; the module's pure rules already compile into this suite (`:54`), which is the load-bearing trick for testing multiplayer without the SpacetimeDB CLI (frequently absent in agent environments per `CLAUDE.md`).

1. **Pure match-rules unit tests** (`module/src/matchRules.test.ts`): every reducer-equivalent op — handshake accept/reject (wrong hash, wrong compilerVersion, cross-track), multi-match isolation, pickup claim races (two claimants, one socket), per-weapon hit validation tables (immunity, grace, specter windows, damage caps, kill/refund), energy settlement math (drain/strip/nanite/overdrive over odd elapsed intervals, fatal-boost zero-crossing), respawn token lifecycle, countdown clamp, DNF mid-combat. Same style as the N0 pure ops (`rules.ts:225+`).
2. **Simulated-latency harness** (`src/net/netsim/`, test-only): a deterministic event-queue scheduler wrapping the pure `MatchDb` + per-client delay queues (configurable one-way delay, jitter, drop — drop for pose publishes only; reducer calls are reliable in the real transport, so "loss" models tab throttling as burst delay). Clients are scripted bots: the kinematic AI driver (`raceSim.ts` machinery) produces 60 Hz poses; the harness publishes at 15 Hz through the queue, fires scripted weapons, claims hits from an interpolated view (mirroring `interpolateGhost`'s 120 ms buffer). Assertions at 50/100/200 ms RTT: zero valid-flow reducer rejections; lap/finish convergence; hit-claim acceptance ≥ threshold; specter-vs-seeker race resolves victim-favored when specter leads by > RTT; energy divergence between client prediction and server settlement ≤ ε at settle points; respawn round-trip ≤ 1 s + RTT + margin. Deterministic (seeded), so failures replay exactly — this is the P4 equivalent of the golden-hash contract.
3. **Bot-vs-bot network soaks** (`scripts/net-soak.mjs`, CI-optional like `soak:fallthrough`): the §8.2 harness looped over seeds × tracks × RTT profiles × 8 bots with weapons hot, asserting no invariant violations (negative energy, double-kill, stuck destroyed, orphaned mines, un-respawned racers, match never finishing before `FINISH_TIMEOUT`).
4. **Deterministic replay regression** (existing, kept): golden hash (`GameRuntime.test.ts`), combat replay (`combatReplay.test.ts:162-196`), compiler 600-tick replay — these guard the shared math both sides now depend on. Plus a new **settlement replay**: harness records the accepted reducer log; re-running the log against fresh pure rules must reproduce the final `MatchDb` hash (audit property that also underwrites the §5.4 roll audit).
5. **Real-transport smoke** (piloted, per milestone): `pnpm build:test` harness build (`__KZERO_TEST__` hooks stripped from prod, `assert:no-test-hooks`) driven via chrome-devtools-axi against a **maincloud dev database** (second DB name, e.g. `kzero-dev` — cloud-hosted per the hard constraint; local `spacetime start` remains a developer convenience where the CLI exists, never the plan of record). Scenarios scripted in `docs/qa/phase-p4-*` manual test plans following the existing convention (`docs/qa/QA_GATES.md` severity/gate format, `phase-05-ships-8-manual-test-plan.md` precedent). Latency variation via browser network throttling.
6. **Version-skew tests**: harness pins client contract ≠ server contract → assert structured rejection + UI state; module republish mid-match → frozen match contract honored.

---

## 9. Phased milestones (each a single PR with acceptance criteria)

Ordering principle: schema first behind the existing experimental flag, then one gameplay system at a time onto the live relay, weapons split by resolution class. Every milestone keeps solo modes byte-identical (guarded by the existing suite) and keeps `VITE_MULTIPLAYER_EXPERIMENTAL` gating (`matchMode.ts:14-20`) until M8.

| # | PR | Scope | Acceptance criteria |
|---|---|---|---|
| **M0** | `p3-exit-freeze` | §7.3: Foundry raceSim coverage + balance report script + freeze note in `CLAUDE.md` | Both tracks × 8 bots green in `pnpm test`; `scripts/balance-report.mjs` output committed under `docs/qa/report/`; captain sign-off recorded |
| **M1** | `p4-module-v2` | §3.1 codegen (trackData v2 both tracks + combatTuning.generated + drift checks); module schema v2 (tables §3.2, lifecycle+driving reducers §3.3); **handshake** (§3.4); pure matchRules + tests; bindings regenerated; client minimally rewired (single quick-match path so N0 UX still works); `VITE_STDB_DB`; speed-cap and raceBridge gate-count fixes | `pnpm test` green incl. new matchRules suite; publish to maincloud dev DB; two browsers complete a 3-lap Neon race through a `match` row; join with a mutated client hash → server rejection **and** `incompatible-version` screen (piloted); `pnpm track:check` fails on stale generated module data |
| **M2** | `p4-rooms-ships` | Match browser/create/code/quick-match; lobby ship display + `set_ship`; host `set_track`; Foundry online; per-ship ghost rendering; leave/janitor | Piloted QA (2–3 players): create/join by code and browser; both tracks raced online; ship choices visible on remote craft; disconnect during lobby/countdown/race/finish behaves per N0 matrix; gate progression correct on Foundry's 10 gates |
| **M3** | `p4-energy-online` | `boosting` publish + server lazy energy settlement + strips + fatal boost + server destroy/respawn via token flow (no weapons yet); client predicted energy + reconciliation; HUD parity | Latency harness: energy divergence ≤ ε at 200 ms; fatal boost kills at server-projected time ± 1 publish interval; piloted: boost/strip/fatal-boost/fall respawn all correct online on both tracks; solo untouched (suite green) |
| **M4** | `p4-items-online` | `pickup_state` + `claim_pickup` + server rolls (gap-from-standings) + `absorb_item`; pad visuals from rows; contested-claim UX | Harness: contested claims always single-winner, roll audit reproducible from seed; piloted: two players fight over one row's sockets, 5 s per-socket respawn, absorb grants energy |
| **M5** | `p4-weapons-A` | combatNetBridge skeleton; server hit application core (shield/immunity/caps/kill/refund/grace); **Arc + EMP (server-instant) + Mine (victim-trigger)**; combat events → VFX/telegraphs; kills/deaths in results | Harness at 50/100/200 ms: damage totals match generated tables, immunity/grace respected, EMP clears munitions rows, mine triggers exact vs own pose; piloted 3-player brawl: hits feel ≤ RTT-late, no double-kill, kill refund visible |
| **M6** | `p4-weapons-B` | **Pulse + Seeker (claims) + Rail (scheduled resolve)**; all four utilities server-side + optimistic local apply; specter/seeker race rule; deny events | Harness: claim acceptance ≥ 95 % at 100 ms for scripted true hits, 0 % for scripted fabricated hits; specter leading by > RTT always spoofs; rail resolves identically for all observers; piloted: full-roster race on both tracks reads fair at throttled 150 ms |
| **M7** *(optional, flagged)* | `p4-ghost-collision` | Local kinematic hulls for remote craft behind a setting, default off | Piloted QA judges asymmetric contact acceptable; movement-cap rejections do not spike; feature can ship default-off without blocking M8 |
| **M8** | `p4-release` | Rate limits + reject telemetry + kick; janitor hardening; net-soak in CI (optional lane); prod env wiring (`VITE_STDB_URI/DB` on Vercel); flag flip to expose Online in prod; docs (`README` modes, `CLAUDE.md` P4 section, QA gate doc) | `docs/qa/phase-p4` gate table fully checked (severity rules per `QA_GATES.md`); 30-seed net-soak green at 3 RTT profiles; piloted 4+ player session on maincloud prod DB; captain go/no-go |

Dependency notes: M3 ⊂ M5 (destroy path reused); M5 before M6 (hit-application core); M2 independent of M3–M6 except results fields. If a milestone must split, the natural cleave lines are marked in scope cells (e.g., M5 can split mines out).

---

## 10. Open questions / risks

| # | Question / risk | Impact | Proposed default |
|---|---|---|---|
| Q1 | **P3 exit gate scope**: brief lists "AI item use + balance instrumentation" as landed; neither is (§1.2). Does the captain require bot *combat* balance evidence before the freeze, or is racing-balance + caps-tests sufficient? | Blocks M0 definition | Proceed with §7.3 as specified (racing bands both tracks + caps tests + report); treat AI item use as post-P4 or parallel P3c |
| Q2 | **maincloud latency/energy budget unmeasured.** Reducer round-trip and subscription-delta latency on the captain's plan, and energy cost of 15 Hz × 8 publishes/match, are assumptions (§3.5). | Could force publish-rate reduction (15→10 Hz) or batching | M1 includes a measurement spike (scripted 8-client publish storm against the dev DB; record p50/p95 RTT + billing counters) with go/adjust thresholds written into the PR |
| Q3 | **Event-table semantics** (`event: true`): server-side persistence/pruning behavior and delivery guarantees for `combat_event` under the 2.6 TS SDK need verification (`module/CLAUDE.md` describes client-cache behavior only). | Fallback is a normal table + scheduled pruning | Verify in M1 spike; design tolerates either |
| Q4 | **Client clock skew** for countdown/telegraphs handled by an EWMA offset (§4.2) — is ±100 ms adequate for the 3-2-1 read? | Cosmetic | Ship EWMA; revisit only if QA flags it |
| Q5 | **Track `set_track` vs. match recreation**: allowing host track switch in lobby re-freezes the contract; simpler alternative is "track fixed at create". | Small UX/complexity tradeoff | Keep `set_track` (one reducer); cut if M2 runs long |
| Q6 | **Mine pull-field fidelity online**: v1 applies pull-slow only on core trigger (§5.2); the 7 m cosmetic pull is client-side feel. Acceptable divergence from offline? | Minor gameplay parity | Yes for v1; note in QA plan |
| Q7 | **Energy prediction visible snapping** when server settlement disagrees (packet bursts): HUD lerp vs snap policy. | Polish | Lerp ≤ 150 ms unless death/pickup (snap); tune in M3 QA |
| Q8 | **Vercel preview auth constraint** (`CLAUDE.md` Commands): PR commits must stay attributed to `lee.barry84@gmail.com` for preview deploys — matters for M2+ piloted QA links. | Process | Follow existing rule |
| Q9 | **Rejoin-with-different-build mid-match**: a client that refreshes into a newer deploy during a race will fail the (implicit) contract if the track data changed in between. | Rare edge | Rejoin path re-runs the same handshake as join; mismatch → spectator-less clean exit + DNF grace as today. Document in QA plan |
| Q10 | **Scaling beyond one lobby per identity** (tournaments, spectators) is explicitly out of P4 scope. | Scope guard | Note in README modes section at M8 |

Primary schedule risk: M5/M6 (combat bridging) carry the most novel code (`combatNetBridge`); mitigated by the latency harness landing in M3 (its scheduler is a M1/M3 by-product) so weapon PRs arrive with executable specs instead of manual-only QA.

---

## 11. Rejected alternatives

| Alternative | Where considered | Why rejected (grounded) |
|---|---|---|
| Full server-authoritative physics (inputs up, state down) | §2.2-A | Rapier WASM cannot run inside a SpacetimeDB module (`module/CLAUDE.md` determinism/no-I/O rules); pure-TS rewrite of suspension + slab collision re-opens the P1 fall-through bug class (`CLAUDE.md` sharp edge); adds full RTT to steering, violating the P1.2/P1.4 feel contract; 60 Hz server tick × 8 racers = heavy maincloud reducer/subscription load |
| Deterministic lockstep over input relay | §2.2-B | Determinism contract is "same-build local replay only" (`CLAUDE.md`); catch-up clamp (`constants.ts:7-8`) would desync rather than stall; input delay ≥ RTT through reducer+subscription; one slow peer stalls all; no state-resync path exists for a Rapier world |
| Rollback/prediction (GGPO-style) | §2.2-C | Same cross-client determinism gap; requires per-frame Rapier world save/restore + N-tick resim in browser JS — weeks of work and new perf/visual failure modes; disproportionate for 2–8 friendly players; retained as the documented future upgrade since Option D already centralizes discrete outcomes |
| WebRTC P2P mesh (host-authoritative or lockstep) | §2.2 wrap-up | Violates the SpacetimeDB Cloud hard constraint; adds signaling/NAT infrastructure, host-advantage and host-migration problems N0 already solved server-side (host election, `module/src/index.ts:185-190`) |
| Server-simulated combat world (run `tickCombatWorld` in a scheduled reducer) | §5.1 design | Technically possible (combat world is pure TS) but: per-tick projectile row churn or private-row transactions at 30–60 Hz per match on paid cloud; hit tests against 15 Hz-stale victim poses systematically favor "shots that missed on the shooter's screen"; and it doubles the sources of truth for munitions. The per-weapon split (§5.2) captures the authoritative benefits where they matter (area weapons, rail, mines) without a server game loop |
| Per-tick server energy mutation | §3.3 | 60 Hz writes/racer are absurd on a billed cloud DB; lazy settlement on 15 Hz publishes + scheduled zero-crossing gives identical outcomes with ~0 extra load |
| Client-supplied damage / victim-applied-only damage | §5.2 | Client damage = trivial cheat; victim-only application lets a hacked victim ignore hits. Server application against generated tables is the only stable point |
| Hand-maintained server constants (N0 status quo) | §3.1 | Already produced the 80 vs 88/105 speed-cap drift bug (§1.3) — the strongest in-repo evidence that every shared constant must be generated |
| Colliding remote craft in v1 (server- or client-resolved) | §2.3 | No authority can fairly resolve hull contact between two client-authoritative poses; N0 ghosts are proven; local-kinematic compromise is scheduled as flagged M7 with QA gate rather than a v1 bet |
| Multi-column composite PKs / per-match transform tables | §3.2 | The documented TS SDK PK surface is a single-column `.primaryKey()` modifier — multi-column is documented for btree *indexes* only (`module/CLAUDE.md`, Column Types / Indexes); identity-PK + `match_id` index preserves every N0 authority check unchanged |

---

## Appendix A — Evidence log

Environment: read-only audit of worktree `/Users/leebarry/.treehouse/k-zero-7c110f/2/k-zero` at `91511a6`. No builds, publishes, or code changes were made (planning-only task; `pnpm install` unnecessary since no execution was required).

Key commands run (abridged):
- `find src module docs scripts -type f` — inventory (§1 tables)
- `git log --oneline -30` — landed-feature verification (§1.2): last commit #21 ships; no AI-item-use or balance-instrumentation commits exist
- `grep -rn "fireWeapon|useUtility|inventory|item" src/game/ai/` → `ai/index.ts:3` "No weapon/item use in this slice"; `driver.ts:361-362`
- `grep -n "countdown" src/game/craft/ src/game/race/RaceController.tsx` → no input gating during countdown (§1.3, §6)
- `grep -n "maxSpeed|SAFETY|terminal" src/game/craft/tuning.ts` → 70/88/105 vs module 80 (§1.3)
- Full reads: `module/src/index.ts`, `module/src/rules.ts`, `src/net/{spacetime,transformSync,matchAdapter,matchMode,raceBridge,useLobby,gridSpawn}.ts`, `src/game/runtime/{GameRuntime,constants}.ts`, `input/{InputIntent,InputRingBuffer}.ts`, `src/game/weapons/{combatWorld,playerCombat,weaponTuning}.ts`, `src/game/craft/{PlayerCraft.tsx,craftCatalog.ts}`, `src/game/ai/{AiField.tsx,raceSim.ts,raceSim.test.ts}`, `src/game/race/raceState.ts`, `src/game/track/{catalog.ts,compiler/{artifactTypes,codegen,cli,quantize}.ts}`, `src/game/energy/energyTuning.ts`, `src/game/items/pickups.ts`, `src/hud/Lobby.tsx`, `src/App.tsx`, `src/game/GhostCraft.tsx`, `module/{spacetime.json,spacetime.local.json,package.json,CLAUDE.md}`, `package.json`, `scripts/test.mjs`, `docs/qa/QA_GATES.md`, `README.md`

Notable single facts a reviewer should be able to re-verify in seconds:
- `module/src/trackData.generated.ts:8` → `GAMEPLAY_HASH = 1964167107` (Neon, trackVersion 3)
- `module/src/rules.ts:13` → `MAX_SPEED_MS = 80`; `src/game/craft/tuning.ts:146,152` → 88/105
- `src/net/raceBridge.ts:5` → `if (... n > 7) throw` vs Foundry's 10 checkpoints
- `src/game/craft/PlayerCraft.tsx:362` → `const soloLiteralRespawn = adapter?.mode !== "online"` gating the entire P2 stack out of online
- `module/spacetime.json` → `"server": "maincloud"` (Cloud target pre-configured)
- `scripts/test.mjs:54` → module pure rules already run in the root test suite (basis for §8's CLI-free approach)

**Ship-worthy fixes discovered (could be promoted independently of P4):** the three §1.3 bugs — module speed cap vs boost envelope, `raceBridge` 8-gate hardcode, hardcoded client DB name — are each small, isolated, and testable today.
