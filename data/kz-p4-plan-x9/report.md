# K-ZERO P4 — Multiplayer v1 on SpacetimeDB Cloud

Planning scout report · checkout `91511a66220f` · 2026-07-13

## Executive decision

Build P4 as a **server-authoritative 60 Hz race/combat simulation, advanced by one SpacetimeDB Cloud scheduled reducer transaction every 50 ms (three fixed substeps), with 60 Hz local input prediction/reconciliation and buffered interpolation for remote racers**.

“Server-authoritative” is the selected netcode model. Prediction is a client latency-hiding technique, not a second authority: the server owns movement, racer contacts, track progress, energy, inventory, pickups, weapon entities, hits, destruction, respawn, finish order, and results. The browser sends only quantized input frames. It never submits a pose, checkpoint, pickup, hit, damage value, or item roll.

This choice fits the landed fixed-tick/input and pure combat seams, but it does **not** assume the current game is a complete portable deterministic simulation. `GameRuntime` owns a deterministic tick/RNG/input/system shell, while suspension raycasts and rigid-body integration still happen in browser Rapier. The current golden hash explicitly covers “same-build local replay” and includes body metadata plus optional pose proxies, not the Rapier world (`src/game/runtime/determinism/goldenHash.ts:4-19`; `src/game/craft/craftPhysics.ts:71-206`; `src/game/runtime/FixedStepDriver.tsx:150-177`). An early authority-core milestone must therefore move online movement state into a pure, server-compatible integrator and prove that its handling remains acceptably close to the current craft before P4 expands into combat.

Two gates precede schema freeze:

1. The missing P3 exit gate must land: item-using AI, balance instrumentation, and eight-bot fairness suites on **both** Neon Orbital and Black Rain Foundry.
2. The authoritative movement/cadence spike must pass deterministic, handling-parity, and SpacetimeDB Cloud tick-cost gates, because its required state fields define the frozen P4 protocol.

Hosting is **SpacetimeDB Maincloud only**. The repository already points the module at `maincloud` (`module/spacetime.json:1-3`), while the browser still defaults to `ws://127.0.0.1:3000` and database `kzero` (`src/net/spacetime.ts:71-75`). P4 replaces that browser default with `https://maincloud.spacetimedb.com` plus an explicit Cloud database name. It will use separate Maincloud development, staging, and production databases under the captain's subscription; this plan contains no self-hosted SpacetimeDB environment or lifecycle.

## What I inspected and what is actually landed

### Runtime and net boundary

- `GameRuntime` is a plain ordered fixed-tick runtime with a seeded RNG, integer tick, body-registration gate, and one quantized input ring (`src/game/runtime/GameRuntime.ts:55-88`, `195-224`, `328-364`). The ring consumes one frame per tick, overwrites oldest input when full, and repeats the last input when empty; it already copies all eleven intent fields explicitly (`src/game/runtime/input/InputRingBuffer.ts:4-11`, `35-79`).
- `QuantizedIntent` already has the complete network-facing axes: thrust, brake, steer, drift, boost, two airbrakes, sideshift, air pitch, weapon fire/absorb, and utility use (`src/game/runtime/input/InputIntent.ts:6-32`, `64-110`). Add tick/sequence metadata around this payload; do not invent a second input vocabulary.
- Craft force calculation is pure (`src/game/craft/craftController.ts:1-5`), but its `CraftBodySnapshot` includes four suspension-pad hits and velocities supplied by Rapier (`src/game/craft/craftController.ts:59-94`). `craftPhysics.ts` performs the world raycasts, reads the Rapier body, applies force/torque, and lets Rapier integrate (`src/game/craft/craftPhysics.ts:71-206`, `209-230`). This is why full lockstep is not ready.
- The current online path is N0 containment, not authoritative multiplayer. The client publishes its Rapier pose and velocity at 15 Hz (`src/net/transformSync.ts:77-153`); the server accepts the client pose after velocity/distance plausibility checks (`module/src/index.ts:471-565`); remotes render as interpolated, non-colliding boxes 120 ms behind (`src/net/transformSync.ts:159-199`; `src/game/GhostCraft.tsx:7-31`, `55-65`).
- Online energy, pickups, inventory, weapons, damage, and literal-pose destruction are intentionally disabled. `PlayerCraft` gates that whole path behind `adapter?.mode !== "online"` and says P4 owns online combat arbitration (`src/game/craft/PlayerCraft.tsx:355-426`, `457-607`). P4 must move these rules to authority; it cannot merely synchronize existing local combat.

### Existing SpacetimeDB scaffold

- The module has one public `player`, one `race`, one `participant` per identity, and one client-authored `transform` per identity (`module/src/index.ts:23-83`). `activeRace()` returns the first race, and `init` creates exactly one lobby (`module/src/index.ts:130-134`, `280-291`).
- `join_lobby` assigns one of eight compiled Neon grid slots; `set_ready` starts a three-second scheduled countdown when at least two connected racers are all ready (`module/src/index.ts:337-417`). Reconnect grace is already 15 seconds (`module/src/index.ts:294-335`; `module/src/rules.ts:11-24`). These are useful lifecycle rules to preserve, but they are single-room and single-track.
- The current server accepts a client-authored checkpoint number and only validates order/minimum split (`module/src/index.ts:568-622`). The client bridge also hardcodes checkpoints `0..7` (`src/net/raceBridge.ts:4-6`). P4 must derive swept checkpoint crossings from the match's artifact on the server.
- Pure N0 rules and a two-client lifecycle test are valuable migration fixtures (`module/src/rules.ts:1-5`; `module/src/rules.test.ts:239-330`), but there is no live Cloud integration harness today. Generated bindings expose only the seven N0 reducers and four public tables (`src/net/bindings/index.ts:1-76`).
- The root module instructions reinforce the correct security model: reducers are transactional and return no data; subscriptions carry outcomes; auto-increment IDs are not ordering; `ctx.sender` is the principal (`module/AGENTS.md`). The proposed schema follows those constraints with explicit sequence columns and an admission row rather than a reducer return value.

### Tracks and compatibility contract

- The compiler contract already defines `{ compilerVersion, trackId, trackVersion, gameplayHash, artVersion }` and marks gameplay hash changes breaking (`src/game/track/compiler/artifactTypes.ts:1-15`, `201-215`). The hash covers quantized geometry/frames, AI line/speed, checkpoints, boosts, recharge strips, pickup sockets, grids, respawn poses, and the spatial index (`src/game/track/compiler/quantize.ts:113-169`).
- Checked-in contracts are:

  | Track | Compiler | Track version | `gameplayHash` | Art version |
  |---|---:|---:|---:|---:|
  | Neon Orbital | 2 | 3 | `1964167107` | 1 |
  | Black Rain Foundry | 2 | 1 | `3445598386` | 1 |

  Evidence: the `contract` objects in `src/game/track/compiled/neonOrbital.artifact.ts:6` and `src/game/track/compiled/blackRainFoundry.artifact.ts:6`.
- The compiler currently emits server data only for Neon. `REGISTRY` gives only Neon a `moduleDataPath`, and the Foundry entry says it is solo-only until match hashes land (`src/game/track/compiler/cli.ts:17-40`). `module/src/trackData.generated.ts` exports Neon `GAMEPLAY_HASH`, but the server never reads it for admission (`module/src/trackData.generated.ts:5-9`). The code comment already names the P4 handshake (`src/game/track/compiler/codegen.ts:19-47`).
- The client catalog contains both tracks (`src/game/track/catalog.ts:18-59`), yet online always forces the default Neon key (`src/App.tsx:111-120`, `147-161`; `src/net/matchMode.ts:39-49`).

### Ships, AI, items, and combat

- There are exactly eight persisted ship IDs—Agile, Razor, Viper, Balanced, Pulse, Nova, Heavy, Bulwark—and ships are visual-only with shared handling (`src/game/craft/craftCatalog.ts:1-31`; `README.md:42`). Online currently saves the selected family locally and then enters the Neon scene; the join reducer never receives it (`src/App.tsx:163-195`; `src/hud/Lobby.tsx:66-98`).
- The P3 premise in the task is ahead of this checkout. The AI package explicitly says “No weapon/item use,” the eight-bot suite imports only Neon, and the live `AiField` is mounted only for Neon (`src/game/ai/index.ts:1-6`; `src/game/ai/raceSim.test.ts:1-16`; `src/game/Scene.tsx:235-248`). The headless race is a kinematic AI-line integrator, not the Rapier/combat race (`src/game/ai/raceSim.ts:1-7`, `114-169`). Repository search found no grid fairness/win-rate/combat balance suite. This is an unmet prerequisite, not a reason to weaken the captain's P3 exit gate.
- The reusable gameplay rules are strong. Pickup simulation is pure, artifact-positioned, seeded, and has per-socket five-second cooldown (`src/game/items/pickups.ts:1-7`, `30-60`, `135-159`). Inventory owns one weapon and one utility, a 0.6-second absorb hold, release-to-fire, and utility rising edge (`src/game/items/inventory.ts:1-39`, `161-170`).
- `combatWorld.ts` is fixed-tick, seeded, and Rapier-free, and already models all six weapons and four utilities (`src/game/weapons/combatWorld.ts:1-6`, `93-225`). Central tuning enforces 120 ms same-family re-hit immunity, at most 450 ms stun, at most 25%/1.2 s slow with a three-second diminish window, and no full-energy one-shot (`src/game/weapons/weaponTuning.ts:48-69`). Rail has a real 0.65-second charge and stored aim corridor (`src/game/weapons/weaponTuning.ts:169-186`; `src/game/weapons/combatWorld.ts:850-924`); Seeker produces lock/threat telegraphs (`src/game/weapons/combatWorld.ts:784-848`); shield absorption, utility disable, kill refund, and hit events are centralized in `applyHit` (`src/game/weapons/combatWorld.ts:1013-1159`). These functions should become the single shared online authority, not be reimplemented as UI reducer calls.

### Baseline verification

Commands were run from the clean checkout:

```text
$ git rev-parse --short=12 HEAD
91511a66220f

$ git status --short
# no output (clean)

$ pnpm track:check
✓ generated track artifacts are up to date

$ pnpm test:unit
tests 232; pass 232; fail 0; duration_ms 507.714083
```

The passing suite includes the N0 two-client lifecycle, eight-AI Neon race, both-track line-bot smoke, fixed runtime/input/golden hashes, track compiler/hash guards, energy/items, and the full weapon/utility unit/replay suite. It does **not** prove live Cloud tick cadence, full deterministic Rapier simulation, two-track item-using AI balance, or network reconciliation.

Selected audit commands and outputs that drove the gap analysis:

```text
$ rg -n "No weapon/item use|blackRainFoundryArtifact|raceVsAi.*neon" src/game/ai src/game/Scene.tsx
src/game/ai/index.ts:3: * No weapon/item use in this slice.
# raceSim.test.ts imports neonOrbitalArtifact only; Scene gates AiField to neonOrbital

$ perl -ne 'if (/"contract":(\{[^}]+\})/) { print "$ARGV: $1\n"; exit }' src/game/track/compiled/*.artifact.ts
blackRainFoundry.artifact.ts: {"compilerVersion":2,"trackId":"black-rain-foundry","trackVersion":1,"gameplayHash":3445598386,"artVersion":1}
neonOrbital.artifact.ts: {"compilerVersion":2,"trackId":"neon-orbital","trackVersion":3,"gameplayHash":1964167107,"artVersion":1}

$ rg -n "activeRace|publish_transform|cross_checkpoint" module/src/index.ts
130:function activeRace(ctx: any) {
471:export const publish_transform = spacetimedb.reducer(
568:export const cross_checkpoint = spacetimedb.reducer(

$ command -v spacetime
# no output
```

The SpacetimeDB CLI is absent in this scout environment (`command -v spacetime` produced no path), so I did not build/publish a module or regenerate bindings. No implementation code, remote writes, pushes, or PRs were made.

## Target architecture

```text
keyboard/gamepad
     │ sample + quantize at client tick
     ▼
InputRingBuffer ── 3-frame batch / 50 ms ──► submit_input_batch reducer
     │                                             │ validates sender, seq,
     │ immediate prediction                        │ tick window, axes, rate
     ▼                                             ▼
pure online sim core ◄── same rules ───── scheduled match_tick (50 ms)
     │ 60 Hz local                              3 × 60 Hz substeps
     │                                             │
     │ retain unacked inputs                        ├─ movement/contact/progress
     │                                             ├─ pickups/inventory/energy
     │                                             └─ combat/destruction/results
     │                                             │
     ◄──── racer_state + ack + snapshot hash ──────┤
     │ rewind/replay unacked; smooth visual error  │
     ◄──── combat_entity / pickup_state ────────────┤
     ◄──── match_event (ephemeral, confirmed VFX) ─┘

remote racer rows ── 100–150 ms interpolation buffer ──► eight real ship meshes
```

### Tick, input, and synchronization model

1. **Canonical time:** every match has `authoritative_tick`, a 60 Hz integer. Wall-clock timestamps start/cancel countdowns and determine how many ticks are due; gameplay uses tick numbers only.
2. **Cloud cadence:** one private scheduled row per active match uses `ScheduleAt.interval(50_000n)`. Each `match_tick` transaction advances three 1/60-second substeps and writes one consolidated snapshot. Official SpacetimeDB docs explicitly support interval schedules for game ticks and show 50/100 ms examples; 50 ms is still a benchmarked design target, not an assumed SLA. Process at most five catch-up substeps per callback (matching the current runtime's bounded catch-up intent), retain tick debt, and end the match with `server_overrun` rather than silently skipping gameplay if debt remains above twelve ticks for three callbacks.
3. **Input transport:** `submit_input_batch` accepts 1–6 `InputFrame` products. Normal batches carry three consecutive frames every 50 ms. Each frame wraps the existing eleven-field `QuantizedIntent` with `client_tick` and monotonic `seq`. WebSocket delivery is reliable/ordered, so duplicates are idempotent but there is no UDP-style redundant packet scheme. The server rejects future frames beyond +2 ticks, stale frames older than the retained history, invalid axes/enums, non-monotonic duplicates, oversized batches, or calls from a non-racing identity. A missing hold is sticky for at most six ticks; then the server applies a fully neutral intent so a disconnected client cannot leave boost/fire held forever. Sideshift and fire/utility edges are deduplicated by sequence/tick.
4. **Server state:** the authority runs a deterministic pure `module/src/sim-core/` with no Spacetime imports. This directory is inside the module build boundary and is also compiled into the browser predictor by adding it to the root TypeScript build. Extract/port the landed craft, energy, item, combat, control-loss, race, seeded-RNG, and track-query rules there so reducers and prediction do not fork balance logic. The online movement core owns numeric body/controller state, artifact surface sampling, swept surface/checkpoint tests, and simplified racer contact impulses. Quantize position, velocity, quaternion, and controller state at tick boundaries. Solo continues using dynamic Rapier.
5. **Authority state vs. replication:** private `sim_match`/`sim_racer` rows hold all integrator, RNG, inventory, combat, and history state required to resume deterministically. Public `racer_state` rows are the latest compact fixed-point snapshot. One snapshot per 50 ms carries `server_tick`, `snapshot_seq`, `last_processed_input_seq`, pose/velocity, status/energy, inventory/utility summary, progress, and reconciliation hash. `combat_entity` and `pickup_state` carry durable live entities; `match_event` carries transient confirmed fire/hit/kill/pickup/telegraph/VFX events.
6. **Local reconciliation:** the client predicts its own racer at 60 Hz and retains at least 250 ms of state/input history. On a snapshot, restore the authority state at its acknowledged tick, discard acknowledged inputs, replay the remaining frames, and apply only the resulting pose to the presentation proxy. Smooth small errors over 100 ms; snap only on respawn/destruction, server anti-cheat correction, or an error over 3 m/12°. Remote racers never predict local input: interpolate two server snapshots 100–150 ms behind and cap extrapolation at 100 ms.
7. **Online physics boundary:** online R3F/Rapier bodies become kinematic presentation/contact proxies driven from the pure predicted/interpolated state. Server contact events are authoritative and feed prediction impulses. Do not let a remote interpolated Rapier collision mutate authoritative local state. The current 60 Hz `FixedStepDriver`, camera/VFX render-rate boundary, input sampling, and HUD stores stay; only the online craft adapter changes.

### Why 20 Hz replication around a 60 Hz authority

At the normal 70 m/s and 88 m/s boost terminals (105 m/s safety cap), a craft moves 3.5/4.4/5.25 m in 50 ms (`src/game/craft/tuning.ts:137-152`). Therefore every server collision, pickup, and checkpoint test must be swept across the three internal substeps; a single 20 Hz point overlap is unacceptable. Three substeps preserve the existing tuning rate, while one transaction/snapshot per 50 ms bounds table writes and client bandwidth. The Cloud spike may choose a faster transaction interval only if Maincloud measurements justify its energy/cost; it may not lower the internal 60 Hz gameplay rate without retuning all tick constants.

## SpacetimeDB v1 schema

Place declarations in `module/src/schema.ts`, reducers by domain in `module/src/reducers/{admission,lobby,input,lifecycle,tick}.ts`, pure authority in `module/src/sim-core/`, and keep `module/src/index.ts` as schema/export composition. Every gameplay lookup below has a primary key or B-tree index; no hot reducer scans an entire table. Auto-increment IDs are identifiers only—`snapshot_seq`, `event_seq`, input `seq`, and ticks provide ordering.

### Public/subscribed state

| Table | Key/indexes | Required fields | Purpose |
|---|---|---|---|
| `player_profile` | PK `identity` | `name`, `color`, `online`, `last_seen` | Sanitized display identity. `ctx.sender` is always the write principal. |
| `match` | PK `id`; B-tree `(status, track_id, compiler_version, gameplay_hash)` | `visibility`, `status`, `track_id`, `track_version`, **`compiler_version`, `gameplay_hash`**, `protocol_version`, `balance_version`, `seed`, `lap_count`, `max_players`, `host_identity?`, `countdown_ends_at?`, `started_at?`, `finished_at?`, `finish_deadline?`, `authoritative_tick`, `snapshot_seq`, `event_seq`, `created_at` | Durable room/race authority and mandatory compatibility contract. Room codes are not stored here. |
| `admission` | PK `identity`; index `match_id` | `match_id?`, `status` (`searching/admitted/incompatible/full/closed`), `reason_code`, expected/received compiler/hash/protocol, `updated_at` | Reducers return no data, so this RLS-protected row is the clean join outcome. A mismatch writes `incompatible`, inserts no participant, and grants no input rights. |
| `match_player` | PK `identity`; index `match_id`; unique `grid_slot` enforced per match in reducer | `match_id`, `ship_id`, `grid_slot`, `ready`, `role`, `online`, `ghosted`, `disconnected_at?`, `finished`, `dnf`, `finish_rank?`, `finish_tick?`, `best_lap_ticks?`, `last_received_input_seq`, `last_processed_input_seq` | One active match per identity. `ship_id` is a validated `u8` mapping to the eight catalog IDs and locks at countdown. |
| `racer_state` | PK `identity`; index `(match_id, snapshot_seq)` | `match_id`, `server_tick`, `snapshot_seq`, fixed-point pose/linear+angular velocity, progress/lap/gate, energy/status/death+grace ticks, weapon+utility/absorb/control summary, `last_processed_input_seq`, `state_hash` | Compact latest authoritative state for prediction, HUD, results, and rejoin. |
| `pickup_state` | PK deterministic `id`; index `(match_id, socket_id)` | `match_id`, `socket_id`, `available`, `respawn_at_tick?`, `claim_seq` | Artifact socket ownership. Server advances respawn and resolves claims in the match tick. |
| `combat_entity` | PK explicit `entity_id`; index `(match_id, kind)` | `match_id`, owner/target, kind/family/phase, fixed-point pose/velocity, spawn/arm/resolve/expire ticks | Persistent Pulse/Seeker/Mine/Rail-charge state so late subscribers/rejoiners reconstruct threats. |
| `match_event` (`public: true, event: true`) | index `match_id`; explicit `event_seq` | `match_id`, `server_tick`, `event_seq`, `kind`, actor/target/entity IDs, family, amount, fixed numeric payload | Confirmed muzzle, hit, kill, pickup, telegraph, utility, respawn, and phase events. Clients use `onInsert`, never cache iteration. RLS restricts delivery to current participants. |
| `match_result` | PK `id`; indexes `match_id`, `identity` | track contract, identity/ship/grid, rank/finish/best-lap/DNF, kills/deaths/damage/pickups | Immutable post-race result/diagnostic row retained after active rows are cleaned up. |

Use fixed-point integers in authority/snapshot rows (millimetres, mm/s, quantized quaternion/angles) rather than indexing floats. Use explicit columns or small product types; avoid unversioned JSON payloads. The client subscribes in two lifetimes: identity/admission first, then only the admitted match's rows via typed filtered subscriptions. The present `SELECT *` across every table (`src/net/spacetime.ts:80-101`) must go.

### Private authority state

| Table | Key/indexes | Required fields | Purpose |
|---|---|---|---|
| `room_secret` | PK/unique `room_code`; index `match_id` | `room_code`, `match_id`, `expires_at` | Private six-character room lookup without publishing codes in the match list. Generate from deterministic `ctx.random`, retry collisions. |
| `matchmaking_ticket` | PK `identity`; index `(track_id, compiler_version, gameplay_hash, created_at)` | requested contract, ship/profile, `created_at` | Transactional quick-match queue/fair ordering. Admission exposes its result. |
| `input_frame` | PK `id`; composite index `(match_id, identity, client_tick)` | sender-derived identity, `client_tick`, `seq`, the eleven quantized fields, `received_at` | Unconsumed input only. Delete after processing/history horizon. Ordering is `seq`/tick, never auto-inc ID. |
| `sim_match` | PK `match_id` | next due tick/time, RNG state, event/entity counters, overrun debt/counters, rule versions | Restartable deterministic match state and observability. |
| `sim_racer` | PK `identity`; index `match_id` | full integrator/controller, inventory, energy, control-loss, utility, checkpoint/contact state | Lossless authority snapshot; public `racer_state` is its compact projection. |
| `pose_history` | PK `id`; composite index `(match_id, identity, server_tick)` | compact pose/velocity/status | Last 12 ticks (~200 ms) for bounded instant-weapon lag compensation; prune in `match_tick`. |
| `match_tick_schedule` | PK `scheduled_id`; index `match_id`; `scheduled_at` interval | `match_id` | One 50 ms scheduled callback per countdown/racing match. Delete on terminal/abandoned match. |
| `lifecycle_schedule` | PK `scheduled_id`; index `(match_id, kind)` | countdown, DNF grace, finish deadline, room expiry | One-shot lifecycle timers. The scheduled reducer verifies module sender and current generation/status before acting. |

### Reducer contract

- `quick_match({track_id, compiler_version, gameplay_hash, protocol_version, ship_id, name, color})`: validate profile/ship/contract against the generated server registry, then atomically join the oldest compatible lobby with capacity or create one. Write `admission`; do not trust client versions when constructing `match`.
- `create_room(...)`: same compatibility validation, create `match` from the server registry, create a private code, admit creator, and subscribe them through `admission`.
- `join_room({room_code, compiler_version, gameplay_hash, protocol_version, ship_id, name, color})`: resolve private code, compare the client tuple to **the target match row**, and admit only on exact match.
- `set_ship({ship_id})`, `set_ready({ready})`, `leave_match()`, `request_rematch()`: sender-owned lobby/lifecycle mutations. Ship/track lock when countdown begins. Host has no gameplay authority.
- `submit_input_batch({frames})`: the only high-rate client gameplay reducer. Sender and current membership are derived from `ctx.sender`; validate status/ranges/rate/ticks/sequences and insert idempotently.
- `start_match`, `match_tick`, `apply_disconnect_dnf`, `finish_deadline`, `expire_match`: scheduled/module-only reducers. `match_tick` is the sole gameplay mutation path during a race.
- Remove `publish_transform`, `cross_checkpoint`, and arbitrary fall-respawn from the client protocol after the authoritative milestone. Keep them only behind a temporary N0 compatibility flag until the new two-client movement test passes, then delete and regenerate bindings.

### Mandatory gameplay-hash handshake

This is a release blocker, not an optimization:

1. Extend `src/game/track/compiler/codegen.ts` and `src/game/track/compiler/cli.ts` to emit one checked-in `module/src/trackRegistry.generated.ts` containing both tracks' compatibility tuple and server gameplay data. `pnpm track:check` must fail if either server registry entry drifts from its client artifact.
2. A match row is always created from that registry and stores `track_id`, `track_version`, **`compiler_version`, and `gameplay_hash`**. For the current artifacts those pairs are `2/1964167107` and `2/3445598386`.
3. Before `quick_match`, `create_room`, or `join_room`, `src/net/compatibility.ts` resolves the selected track's local artifact contract. It sends compiler/hash/protocol with the admission request.
4. The reducer performs the same check. On mismatch it upserts `admission.status="incompatible"`, includes expected/received fields, inserts no `match_player`/`racer_state`, and returns normally so the subscribed outcome commits. Every subsequent reducer also requires an admitted participant, so a modified client cannot bypass admission.
5. `src/net/onlineStore.ts` exposes `connecting | browsing | joining | lobby | incompatible | racing | reconnecting | failed`. `src/App.tsx` does not mount `Scene`/Physics until `admitted` and the match track has loaded. `src/hud/IncompatibleVersion.tsx` renders a clean “Incompatible race version — update/reload or return to Online” state, with technical expected/installed tuple in a disclosure. It is not a console-only reducer error.
6. Add `protocol_version`/`balance_version` alongside the required track tuple because a track hash does not cover craft/combat schema changes. Track mismatch and protocol mismatch remain distinct reason codes.

Acceptance includes stale clients against both tracks, wrong compiler with correct hash, correct compiler with wrong hash, direct input calls without admission, reconnect after server hot-swap, and a production-build assertion that no mismatch can enter countdown.

## Matchmaking, rooms, lobby, and race lifecycle

### User flow

1. Preserve `Title → mode → ShipSelect`; the chosen one of eight visual ships is persisted as today.
2. Online continues to `OnlinePlay`: `Quick Match` or `Private Room`, then the two-track selector. Quick Match queues only against the selected track/contract for v1; this avoids an ambiguous “any track” request from a stale client. Private Room offers `Create` or a room-code field.
3. Admission performs the hash handshake. Incompatible/full/closed are explicit shell states. Only `admitted` creates the match-scoped subscription and mounts the selected track.
4. Lobby shows track/contract, code for the creator, all players with real selected ship names/models, 2/8–8/8 capacity, readiness, connection status, and host marker. Players may change ship until ready/countdown. All connected non-spectators ready with at least two racers schedules the three-second server countdown.
5. Countdown locks ship/track/grid, seeds all authority state from compiled grid poses, and accepts a small input buffer but applies neutral drive until tick 0. If connected racers fall below two, cancel back to lobby and clear ready, retaining the current tested behavior (`module/src/rules.test.ts:332-341`).

### Race rules

- The match row chooses one artifact. Grid, checkpoint count, OBBs, recharge/pickup sockets, respawn poses, spatial lookup, and AI line all come from that same generated registry.
- Checkpoint/lap progression is computed from authoritative swept racer segments against ordered gate OBBs with forward-direction validation. It is monotonic/idempotent and dynamic per artifact; no client checkpoint reducer and no `0..7` hardcode.
- Race finish is the first server substep that completes the final start gate. Ties in the same tick sort by fractional crossing time, then stable grid slot. Persist immutable result rows. Start a post-winner finish window; racers still running at its deadline become DNF. Proposed v1 default is 45 seconds, configurable in one server constant.
- Fatal boost/damage destruction captures the authority pose, revives at exactly +60 ticks with 500 energy, then applies 15 ticks racer ghost and 60 ticks damage grace, preserving landed rules (`src/game/energy/energyTuning.ts:56-73`; `src/game/energy/energy.ts:172-220`). Normal fall recovery remains no-kill safe-frame recovery from artifact poses (`src/game/respawn/fallRecovery.ts:1-9`, `59-106`).
- On disconnect, immediately force neutral input and non-colliding/ghost state; preserve the current 15-second reconnect grace. Reconnecting with the same Spacetime identity before the deadline resubscribes, restores the latest authority state, and resumes prediction from its snapshot. After grace, mark DNF but allow results spectating. During countdown a disconnect can cancel the start; after finish it cannot rewrite results.
- One active connection generation per identity prevents two tabs from driving one craft. A newer authenticated connection either supersedes or rejects the older generation; the policy must be fixed before schema freeze.
- Rematch reuses the room and track contract, resets ready/sim/entity/pickup state, and increments a match generation/seed. A client whose local contract changed between races is re-admitted before readiness.

## Combat, pickups, and latency reconciliation

All inventory/energy/combat mutation runs inside the authoritative 60 Hz substeps using the landed pure rules. The server rolls pickup contents from match RNG and the authoritative seconds-to-leader bucket; clients receive only the awarded item/result.

### Per-mechanic policy

| Mechanic | Authority and latency policy | Client presentation |
|---|---|---|
| Pickup pads | Server swept overlap against available artifact socket. If multiple racers enter on one tick, process a deterministic seed/tick/socket identity hash order so grid slot never has a permanent advantage. First accepted inventory placement commits the per-socket five-second cooldown/roll; later claims lose. | Pad may glow speculatively; slot/toast appears only on confirmed `pickup` event/state. |
| Recharge/fatal boost | Server overlap and integer energy rates every tick. Client predicts bar/boost but reconciles from `racer_state`. | Smooth small energy correction; destruction is always confirmed/snap. |
| Pulse | Spawn three server projectiles at the current accepted authority tick and pose; swept projectile tests through each 60 Hz substep. No victim rewind and no retroactive projectile hit. | Immediate local muzzle/VFX is speculative; entity/event confirms or cancels. Hit marker/damage only after server event. |
| Mine | Server anchors to artifact surface, arms after 0.45 s, owns pull/core and 12 s life. No rewind. | `combat_entity` makes arm/deploy state reconstructable after rejoin; event drives sound. |
| Seeker | Server selects lock from current authority poses, advances homing, and owns damage/stun. Specter activation at its accepted server tick can break future lock, never undo a committed hit. | Target receives immediate server lock event plus persistent seeker row; local HUD preserves the landed telegraph/counterplay. |
| Arc | Only instant weapon granted bounded lag compensation: validate shooter from server pose history and test victim history at `clamp(mapped_input_tick, now-6, now)` (maximum 100 ms). Never trust a client pose or target. | Server hit/miss event is final. |
| Rail | Server starts charge at accepted current tick, stores authority aim, broadcasts charge, and resolves against **current resolve-tick** poses after the existing 0.65 s window. No rewind—the dodge telegraph is the counterplay. | Local charge can start speculatively; confirmed entity/event aligns beam and audio. |
| EMP-Quake | Resolve at accepted current tick against current server world; clear foreign entities, damage/stun, strip/disable utilities atomically. No rewind because retroactive clearing would invalidate already-seen counterplay. | Confirmed wave event; state/entity removals are authoritative. |
| Aegis/Specter/Overdrive/Nanite | Activate at accepted current server tick after inventory/disable validation. They cannot retroactively cancel damage already committed in an earlier transaction. | Client may predict activation animation; HUD/energy/shield follows confirmed state. |

The input-to-server tick mapping is bounded by the latest acknowledged snapshot and a measured client/server tick offset; client-supplied `client_tick` is a hint constrained to the server window, never authority. Keep pose history to twelve ticks but cap Arc use at six ticks initially. Instrument rejected/late inputs and effective telegraph lead at each latency bucket. If 95th-percentile Seeker/Rail defensive lead falls below their design window at the supported RTT, increase server telegraph range/charge rather than widening retroactive rewind.

Confirmed `match_event` rows should use explicit `server_tick` and `event_seq`; ephemeral events are suitable here because SpacetimeDB broadcasts them on commit and retains them in the commitlog, while durable threat entities remain in `combat_entity` for late subscribers. The event-table flag is immutable after publish, so declare it at the schema-freeze milestone. Official reference: [SpacetimeDB event tables](https://spacetimedb.com/docs/tables/event-tables/).

## Proportionate browser anti-cheat

P4 does not need invasive client anti-cheat. It needs to make browser tampering low-value:

- Authenticate every reducer from `ctx.sender`; never accept target identity as authority. Bind one active participant/connection generation to that identity.
- Accept only quantized input. The server computes movement, collisions, progress, item rolls, inventory, energy, cooldowns, projectiles, hits, deaths, respawns, finish, and results.
- Enforce membership/status, compiler/hash/protocol admission, monotonic sequence, tick window, batch/rate caps, input ranges/enums, and neutral-after-timeout in `submit_input_batch`.
- Enforce server-side item ownership, hold/release semantics, entity caps (`48` projectiles, `16` mines, `12` seekers, `4` rail charges in current tuning), family re-hit/control-loss/damage caps, and one-time pickup/socket transitions (`src/game/weapons/weaponTuning.ts:285-296`).
- Use swept track/checkpoint/surface/racer collision and server safe-frame recovery. Remove client-authored pose/checkpoint/respawn token flows rather than layering more plausibility checks on them. The current server's 80 m/s validation is already below the landed 88 m/s boost/105 m/s safety cap (`module/src/rules.ts:11-16`; `src/game/craft/tuning.ts:137-152`), illustrating why input authority is safer than maintaining heuristics.
- Cap active entities and reducer calls per identity/match; record invalid/late/drop counters. Quarantine/kick only after a threshold of impossible protocol frames, not for normal latency. Never punish reconciliation error by itself.
- RLS-protect `admission`/events and keep input/sim/history/room-code tables private. Filter subscriptions to one match to control scraping and bandwidth.
- Store deterministic replay inputs, seed, contracts, periodic hashes, and final stats long enough for diagnostics. Hashes detect divergence; they are not cryptographic attestation.
- Do not spend P4 on obfuscation, client-side secrets, kernel anti-cheat, or trusting a host player. A modified client can automate valid inputs; server authority prevents it from fabricating outcomes.

## Migration from the current solo runtime

### What stays

| Existing authority/seam | P4 use |
|---|---|
| `GameRuntime`, 60 Hz constants, ordered systems, seeded RNG, quantized input/ring | Preserve for solo and client prediction; extend online frames with tick/seq and expose snapshot/restore. |
| Pure craft force/tuning and handling tests | Extract canonical online-safe rules into `module/src/sim-core`; keep Rapier adapter for solo and use parity tests to prevent feel regression. |
| Checked-in quantized track artifacts/compiler/hash | Expand codegen to both-track server registry; make tuple admission mandatory. Art remains presentation-only. |
| Pure energy/items/inventory/combat/control-loss rules | Move/extract into shared sim core and run only on authority in online mode; client mirrors prediction/UI. |
| `MatchAdapter` authority boundary | Expand `SpacetimeMatchAdapter` into match-scoped input/state lifecycle. `LocalMatchAdapter` and zero-network solo stay unchanged. |
| Camera, speed lines, VFX, audio, HUD at render rate | Consume predicted/confirmed state/events; never enter server sim. |
| Existing N0 lobby/reconnect/rematch pure tests | Port as multi-match invariants and keep behavior where still valid. |

### What changes

- Split the monolithic online path out of `PlayerCraft.tsx`: solo keeps `prepareCraftPhysicsStep/applyCraftPhysicsInput`; online reads/writes the pure predicted state and drives a kinematic presentation proxy. The server, not the client, owns destruction and safe-frame decisions.
- Replace `src/net/spacetime.ts`'s global arrays/`races[0]` with `src/net/onlineStore.ts`, two-lifetime filtered subscriptions, explicit disconnect/error/reconnect states, and `VITE_STDB_DATABASE`. Default URI is Maincloud, not localhost.
- Replace `transformSync.ts`'s publisher with `inputTransport.ts`, `prediction.ts`, `reconciliation.ts`, and `remoteInterpolation.ts`. Keep the interpolation idea, but source it from authoritative `racer_state` and render the selected eight ship assets instead of boxes.
- Expand `MatchAdapter` so online phase/progress/state is read from one match ID; remove `reportCheckpoint` from online gameplay and retain it only for solo sensors/telemetry.
- Change `App.tsx` shell to add online selection/admission/incompatible/reconnect states and mount `Scene` only after the match track/contract is known. It must no longer force Neon before admission.
- Replace one-lobby server scans with match-indexed rules. Move pure N0 test logic from a singleton `MatchDb` toward keyed match fixtures and assert isolation across simultaneous rooms.

### Cloud migration/release shape

Do not attempt an in-place destructive conversion of the N0 singleton database. Publish the new schema to new **Maincloud** databases (`kzero-p4-dev`, `kzero-p4-stage`, then a production `kzero-v1`/versioned name), regenerate bindings from the frozen module, and point a canary client at staging before production promotion. Keep the N0 production database read-only during the canary; retire it after the client rollout. Do not use `--delete-data` on production. Maincloud publish/connect guidance is official here: [Maincloud deployment](https://spacetimedb.com/docs/how-to/deploy/maincloud/).

The implementation should use:

```text
spacetime publish <cloud-db> --server maincloud
VITE_STDB_URI=https://maincloud.spacetimedb.com
VITE_STDB_DATABASE=<cloud-db>
```

Pure rule/replay tests remain normal Node tests. Live integration and soaks target the dedicated Maincloud development/staging database; there is no local/self-hosted Spacetime server in this plan.

## P3 exit gate and schema-freeze checkpoint

The present checkout cannot pass the captain's stated exit gate because AI has no item use and the eight-bot test is Neon-only. Before freezing P4 fields:

1. Add deterministic AI inventory/pad/fire/utility policy through the same `InputIntent`, inventory, and combat rules; no physics or damage cheats. Extend live/headless AI to Foundry.
2. Extend `AiRaceSimResult` instrumentation with per-racer item acquisitions/uses, weapon hits/damage/kills, damage taken/deaths, utility activations/effect, control-loss time, pad contention, finish rank/time, off-track/softlock, and rule-cap violations.
3. Run both artifacts with eight bots over at least 16 seeds × eight grid/roster rotations per track. Required pass: 100% complete three laps; zero softlocks/rule-cap violations/full-energy one-shots; every roster item obtains and exercises its intended path across the suite; each bot's mean rank changes by no more than 1.0 across grid rotations; no fixed grid slot wins outside 8–17% across the combined rotated sample; existing tier ordering/lap bands remain true. Record distributions, not just pass/fail.
4. Check in the seed manifest and golden summary/hashes. Review any statistical threshold change explicitly; do not “fix” the gate by changing seeds after seeing failures.
5. Run the authority-core state/cadence spike, then freeze `docs/p4-protocol.md`: table/event flags, field types/quantization, enum IDs, match/input/snapshot/event versions, tick/catch-up/lag-comp windows, eight ship IDs, both track tuples, and combat rule versions. From that checkpoint to v1, only additive compatible schema migrations are allowed unless a new Cloud database/client version is deliberately cut.

This ordering prevents an item/balance rule discovered during P3 completion from forcing a late breaking P4 schema, and respects that SpacetimeDB event-table status cannot be changed after publication.

## Testing and observability strategy

### Pure deterministic/reducer tests (every PR)

- Server replay: same `{protocol, compiler/hash, balance version, seed, ordered input frames}` must produce identical periodic authority hashes, result rows, pickup rolls, combat events, and final state across repeated runs. Different seed/input must diverge.
- Checkpoint serialization/restart: serialize private `sim_match/sim_racer/entities/pickups` at arbitrary snapshot, resume, and compare with uninterrupted run.
- Input protocol: boundaries/ranges, missing/sticky-to-neutral, duplicate/out-of-order/idempotent batch, future/stale windows, disconnect edge clearing, one-shot sideshift/fire/use.
- Multi-match reducer rules: two simultaneous rooms never share players, RNG, inputs, schedules, entities, events, or results; host/leave/rematch cleanup is match-indexed.
- Compatibility matrix: exact pass and all compiler/hash/protocol mismatch combinations on both tracks; mismatch commits a visible admission state but no participant.
- Lifecycle: 2–8 players, all-ready/cancel, finish ordering, 45-second DNF, reconnect at grace -1/0/+1 tick, duplicate tabs, room expiry/rematch.
- Combat replay: every weapon/utility with caps, simultaneous hits/kill refund, EMP atomic clearing, shield/disable ordering, pickup contention/tie order, no retroactive utility undo.
- Preserve `pnpm track:check`, `pnpm test`, production hook stripping, and both-track real Rapier fall-through gate for solo.

### Simulated-latency harness

Add `scripts/net-sim.mjs` around real protocol frames/state/events with a deterministic virtual transport. Matrix at minimum:

- one-way latency 0/25/50/75/125 ms (0–250 ms RTT), jitter 0/10/30 ms;
- app-layer delay/duplicate/reorder/drop 0/1/5% even though production WebSocket is reliable, to exercise reconnect/retry boundaries;
- eight racers at 60 Hz inputs, 20 Hz snapshots; both tracks; packed/high-speed starts; all weapon/utility paths; disconnect/rejoin during countdown, combat, death grace, and finish.

Assertions: no authoritative divergence or double consume; no phantom pickup/hit/finish; acknowledged input replay converges within the next snapshot; under 150 ms RTT/20 ms jitter local correction p95 <1 m and <5°, no non-lifecycle snap >3 m/12°; remote extrapolation never exceeds 100 ms; confirmed event order is monotonic; defensive telegraph lead remains positive and within the weapon's tested counterplay budget. Publish correction/late-input/telegraph histograms so thresholds are reviewable.

### Maincloud integration and bot network soaks

- Generated-binding smoke against `kzero-p4-stage`: two real clients create/join private room, mismatch one build, select different ships, ready, race, finish, rematch, disconnect/rejoin.
- Headless Node bot clients use the real SDK/input batches—never direct table mutation. Run eight clients, both tracks, the frozen seed/roster rotations, items/combat, and deterministic churn.
- PR-bounded soak: 10 three-lap races/track. Nightly/release soak: at least 100 three-lap races/track plus 10% scheduled disconnect/rejoin. Required: zero orphan schedules/inputs/entities, cross-match leaks, duplicate results, reducer panics, invariant/hash divergence, or missed cleanup; all non-DNF bots finish.
- Maincloud performance gates with eight racers and worst-case entity caps: scheduled callback p95 completes under 25 ms, tick debt p99 < one 50 ms callback and never persists above twelve ticks; client bandwidth p95 <128 KiB/s; reducer error/invalid-frame counters separated from normal late input. These are launch budgets to validate in the spike, not claims about current Cloud performance.
- Use the Maincloud dashboard/log/usage metrics for transaction duration, CPU/energy, bytes written/scanned, bandwidth, row counts, and reducer errors. Official docs list these dashboard measures ([Maincloud dashboard](https://spacetimedb.com/docs/how-to/deploy/maincloud/)).

### Piloted QA

At the marked milestones, test two and eight physical browser clients with 0/100/150/250 ms DevTools throttles: close-pack 70–88 m/s steering/contact, each ship as local/remote, both tracks, pickup contention, every weapon/counter, fatal boost/death/rejoin, host leave, private code, mismatch screen, finish/DNF/rematch, reduced motion/flashes, audio/VFX confirmation, and client refresh mid-race. Capture correction and telegraph overlays, not only subjective notes.

## Single-PR implementation milestones

Each numbered item is intended to merge independently with green pre-existing tests. Do not combine adjacent items merely to make the feature look complete.

| PR | Scope and principal files | Acceptance criteria |
|---:|---|---|
| 0A | **Finish P3 AI item use.** `src/game/ai/{itemPolicy,raceSim,AiField}.ts`, reuse items/weapons; no P4 schema. | Eight AI consume artifact pads and use/absorb the full roster through normal intents/rules; deterministic same-seed replay; no AI physics/damage cheats; live Foundry AI enabled. |
| 0B | **Two-track balance/fairness gate.** `raceSim.test.ts`, new `balanceMetrics.ts`, `docs/p3-exit-gate.md`. | Both tracks × 8 bots × 16 seeds × 8 rotations meet the gate above; golden seed manifest/metrics checked in. Only after this is P3 “exit” true. |
| 1 | **Authority-core + Cloud cadence spike.** Introduce pure `module/src/sim-core/{input,track,craft,contact,state,hash}.ts`; browser test adapter; no player-facing network switch. | Deterministic eight-racer replay; both-track 60-second recorded handling traces remain within agreed ride-height/speed/steer/wall-glance targets; 3-substep transaction benchmark and Cloud stage probe meet tick/cost budgets. If not, stop and redesign before schema. Piloted handling A/B required. |
| 2 | **Protocol/schema freeze + both-track registry.** `docs/p4-protocol.md`, compiler codegen/CLI, generated registry, schema definitions/event flags. | `track:check` guards both server contracts; schema review records exact types/enums/quantization; mismatch matrix and migration compatibility compile; no P4 field remains “TBD.” |
| 3 | **Cloud rooms/admission/matchmaking/lobby reducers.** `module/src/schema.ts`, `reducers/{admission,lobby,lifecycle}.ts`, pure multi-match rules, generated bindings. | Maincloud dev publish; two simultaneous 2–8 player rooms isolated; Quick Match/private codes; all eight ships validated; exact hash/protocol rejection writes admission but no player; no table scan in hot paths. |
| 4 | **Client online shell/subscriptions.** `App.tsx`, `src/net/{onlineStore,compatibility,subscriptions}.ts`, `OnlinePlay`, `Lobby`, `IncompatibleVersion`. | Maincloud URI/database config; no localhost default; scene mounts only after admission; filtered match subscription; clean offline/connect/error/incompatible/full/reconnect states; two-browser piloted room/ship/track QA. |
| 5 | **Input/tick/state transport, movement only.** `reducers/input.ts`, `reducers/tick.ts`, private sim/input/schedule rows, `inputTransport.ts`; preserve N0 behind flag. | Eight headless clients drive both tracks; server owns pose/progress; batch validation/idempotency/neutral timeout; snapshot ack/hash; scheduled overrun metrics; no client pose/checkpoint accepted. |
| 6 | **Prediction/reconciliation/remote ships.** `prediction.ts`, `reconciliation.ts`, `remoteInterpolation.ts`, online craft adapter, replace `GhostCraft.tsx`. | Latency harness correction budgets through 150 ms RTT; 100 ms extrapolation cap; remote uses each player's selected GLB/LOD; no remote Rapier authority; close-pack/high-speed piloted A/B passes. Delete N0 transform publisher after this gate. |
| 7 | **Full race lifecycle.** Server swept checkpoints, laps/results, fall recovery, disconnect/rejoin/DNF, cleanup/rematch; update `MatchAdapter`/HUD. | Both tracks, 2/8 players, dynamic gate counts, tie order, exact countdown/death/grace ticks, refresh/rejoin, finish window, host leave/rematch; multi-room soak; piloted lifecycle QA. Remove online `cross_checkpoint`/respawn reducers. |
| 8 | **Energy, pickups, inventory authority.** Extract shared energy/items; `pickup_state`; HUD reconciliation. | Recharge/fatal boost/absorb/drop/roll/5 s respawn exact; simultaneous claim deterministic and statistically grid-neutral; no client roll/claim reducer; latency harness has no double/phantom item. Piloted pad contention QA. |
| 9 | **Projectile/trap combat.** Pulse, Mine, Seeker plus combat entities/events and lock threats. | Swept projectile hits, mine arm/pull, seeker/Specter lock behavior, caps/refunds/destruction; predicted muzzle but confirmed hit marker; rejoin reconstructs threats; 0–250 ms matrix and piloted counterplay. |
| 10 | **Instant/heavy combat + utilities.** Arc bounded rewind; Rail current-resolve telegraph; EMP atomic current-world; Aegis/Overdrive/Nanite and remaining Specter paths. | Full roster parity with existing unit suite; lag policies above pinned by tests; caps never violated; utility never retroactively undoes a committed hit; full eight-player combat pilot and VFX/audio/reduced-effects QA. |
| 11 | **Soak, hardening, observability, release.** `scripts/net-sim.mjs`, Cloud bot runner, dashboards/runbook, production config/canary. | 10-race PR and 100-race/track release soaks green; bandwidth/tick/cleanup/security budgets pass; mismatch canary and rollback to N0 endpoint rehearsed; production uses Maincloud only; final piloted sign-off. |

## Rejected alternatives

| Alternative | Benefit | Why it is rejected for P4 | Evidence / revisit trigger |
|---|---|---|---|
| Deterministic lockstep among browsers | Tiny state bandwidth; reuses quantized intent stream. | A late frame stalls everyone; a dropped/rejoining peer complicates authority; one modified peer can lie; and current deterministic scope excludes the Rapier world. High-speed weapons need a single durable adjudicator. | Golden hash says same-build local and optional pose proxies (`goldenHash.ts:4-19`); Rapier owns body integration (`craftPhysics.ts:71-230`). Revisit only after full cross-browser physics state is plain data, bit-stable, snapshotable, and server-verified. |
| Peer rollback/full rollback netcode | Excellent local feel and can hide input delay. | Requires snapshot/restore and replay of eight racers, track contacts, all weapon entities, inventory/energy, and RNG; none exists for Rapier. It also does not by itself solve browser cheating or durable Cloud results. | Existing runtime snapshots metadata/inventory/extras, not a physics world (`GameRuntime.ts:297-313`). Revisit for a later peer/fighting mode after authority core and snapshots are proven. |
| Server-authoritative **without** client prediction | Simple and cheat-resistant. | 50–150 ms control latency is unacceptable at 70–105 m/s. | Current craft speed envelope (`tuning.ts:137-152`). Rejected outright; chosen server authority includes local prediction. |
| Keep client-authored transforms and add more plausibility checks | Smallest change from N0. | Cannot prove track contacts, checkpoint crossings, pickups, aim, or collisions; current 80 m/s validator already rejects legitimate 88 m/s boost. Combat would remain exploitable and inconsistent. | `publish_transform` trusts supplied pose (`module/src/index.ts:471-565`); client checkpoint call (`568-622`); speed mismatch above. |
| Trust client hit/pickup reports with server cooldown checks | Low server compute. | A browser can fabricate target, timing, socket, aim, damage, and countermeasure order. Simultaneous pickups and telegraph fairness remain nondeterministic. | Landed combat/pickup functions are already pure enough to run on authority; there is no reason to throw that away. |
| Run the current browser Rapier world inside the TypeScript Spacetime module | Highest nominal solo parity. | The module currently depends only on `spacetimedb`, while browser Rapier is a JS/WASM dependency; nested runtime/packaging support and deterministic Cloud behavior are not established. P4 must not hinge on an unproved nested WASM engine. | `module/package.json:1-8` vs root `package.json:26-40`. Revisit only if an isolated Maincloud spike proves supported build, deterministic replay, cost, and hot-swap restore. |
| One global 60 Hz scheduled reducer scanning all matches | Fewer schedule rows. | Creates cross-match contention, whole-table scans, and failure coupling. | Existing singleton `activeRace()` is the bottleneck being removed. Use one indexed schedule per active match. |
| Update the current N0 Cloud database in place | One endpoint. | P4 replaces primary tables/reducers/event flags and state semantics. A failed automatic migration could strand the only environment. | Use new Maincloud databases and canary; event flags cannot be changed after publish. |
| Self-host SpacetimeDB for development/production | Potential infrastructure control. | Explicitly prohibited by the captain and unnecessary with an active Maincloud subscription. | Rejected permanently for P4. Pure Node tests plus Maincloud dev/stage replace local server integration. |

## Open questions / risks

These do not change the recommended authority model; each has an owner/deadline in the milestones.

1. **Authoritative handling parity (highest risk).** The online pure integrator must reproduce the character of Rapier suspension, slab contact, banking, wall glances, sideshift, and racer shunts. The PR 1 A/B gate needs a recorded input/trajectory corpus on both tracks and piloted sign-off. If it cannot pass without constant correction, stop before schema and either improve the core or prove Rapier-in-module feasibility; do not ship client-transform authority.
2. **Maincloud 50 ms scheduled cadence/cost.** Official APIs permit interval game ticks, but this checkout has no Cloud measurement. PR 1 must measure transaction latency, catch-up, bytes written, energy, and entity worst cases. A 100 ms transaction/6-substep fallback is technically possible but has coarser replication; it requires a new latency/pilot gate, not an invisible downgrade.
3. **Shared-code build boundary.** Canonical pure rules are proposed under `module/src/sim-core/` because `module/spacetime.json` builds from `module/` and `module/tsconfig.json` includes only `src/**/*`, while the browser currently includes only root `src`. PR 1 must prove the root build can compile/import that pure subtree without bringing server schema code into the bundle. If packaging fights this, create a generated checked-in pure package with a drift check—never maintain two handwritten combat rule copies.
4. **Anonymous guest identity vs accounts.** Current identity token is only in `localStorage` (`src/net/spacetime.ts:5`, `75-79`). Guest v1 is sufficient for rejoin on the same browser, but durable names/results across devices need SpacetimeAuth/OIDC. Decide before production schema whether `player_profile` is guest-only; do not block core racing on accounts.
5. **Duplicate-tab policy.** Recommend latest authenticated connection supersedes the old one and forces the old client to spectate, using a connection generation. Product/security must ratify this at schema freeze.
6. **Finish window.** Proposed 45 seconds after first finisher replaces today's broad 300-second safety timeout (`module/src/rules.ts:23-24`). Pilot both tracks and ratify before freeze.
7. **Supported latency/region promise.** The proposed launch gate is good play through 150 ms RTT and graceful, fair degradation to 250 ms. Maincloud region placement and the target player geography must be measured; Arc rewind remains capped at 100 ms even when RTT is higher.
8. **Subscription/RLS design.** Event tables support RLS but not event-table lookup joins/views; match-scoped filters must be tested on the exact 2.6 SDK/protocol. Keep room codes private and avoid relying on an unsupported event join. Sources: [event table limitations](https://spacetimedb.com/docs/tables/event-tables/), [typed/filtered subscriptions](https://spacetimedb.com/docs/clients/subscriptions/).
9. **State row size and hot-match bandwidth.** A single all-purpose racer row is easy but may rewrite unchanged HUD/inventory fields at 20 Hz. Benchmark normalized vs packed snapshots and keep explicit schema/versioning. Acceptance is the 128 KiB/s/client budget, not a guessed encoding.
10. **Reconnect during module/client version rollout.** Track hash alone does not cover sim/combat protocol. `protocol_version` and `balance_version` must gate rematch/rejoin; production needs a canary/rollback window where old and new Cloud databases coexist.
11. **Live bots in public matchmaking.** This plan uses bots for balance and network soak, not to fill public rooms. Adding server-owned live bots affects queue UX, identity/schema, and Cloud cost and should be a post-v1 decision.
12. **Spectators.** V1 supports terminal/DNF result spectating only. Join-in-progress spectators would expand subscriptions, event reconstruction, and privacy; defer unless product explicitly requires it before schema freeze.

## External platform evidence

- [Maincloud](https://spacetimedb.com/docs/how-to/deploy/maincloud/) is the managed deployment target, documents `spacetime publish ... --server maincloud`, `https://maincloud.spacetimedb.com`, hot swaps, and dashboard usage/log metrics.
- [Schedule tables](https://spacetimedb.com/docs/tables/schedule-tables/) explicitly support interval jobs for game ticks and show millisecond-scale examples. P4 still benchmarks the chosen 50 ms interval on the subscribed Cloud account.
- [Subscriptions](https://spacetimedb.com/docs/clients/subscriptions/) replicate filtered rows into the TypeScript client cache and recommend typed, lifetime-scoped queries; this supports identity-first then match-scoped subscriptions.
- [Event tables](https://spacetimedb.com/docs/tables/event-tables/) broadcast transaction-scoped combat/VFX events, retain commitlog history, require `onInsert`, support RLS, and have an immutable event flag—hence their inclusion at schema freeze.

## Conclusion

P4 should replace N0's singleton, client-transform relay with a multi-match, input-only, server-authoritative Maincloud simulation. The fixed 60 Hz input/rule work, compiled artifacts, full pure combat roster, and lifecycle tests provide real leverage. The missing pieces are equally concrete: portable authoritative movement, P3 item-using/two-track fairness, multi-track registry/admission, match-indexed schema, prediction/reconciliation, and Cloud performance evidence. The plan above gates those risks early, makes the required `{compilerVersion, gameplayHash}` handshake an unbypassable admission contract with a clean client state, and then adds lifecycle, items, and combat in independently releasable PRs.
