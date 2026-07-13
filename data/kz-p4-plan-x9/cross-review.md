# K-ZERO P4 cross-review: validated client authority vs. server authority

**Reviewed draft:** `/Users/leebarry/firstmate/data/kz-p4-plan-c5/report.md` (390 lines, read in full)  
**Compared with:** `/Users/leebarry/firstmate/data/kz-p4-plan-x9/report.md`  
**Repository:** `/Users/leebarry/.treehouse/k-zero-7c110f/3/k-zero`, detached `91511a6`  
**Date:** 2026-07-13  
**Scope:** planning critique only; no implementation code, module publish, remote mutation, or PR

## Executive verdict

The c5 draft is a strong audit and a credible plan for an **experimental friends-lobby extension of N0**. It is not a credible claim of end-to-end server authority. It makes the server authoritative over damage arithmetic and row mutation, but it leaves the decisive facts—where a racer drove, whether it crossed a gate, whether boost was held, whether a Pulse or Seeker hit, and whether a victim entered a Mine—to browser assertions. In particular, “server-authoritative outcomes” obscures that Pulse/Seeker hit detection remains shooter-authored and Mine detection remains victim-authored (`c5/report.md:217-233`). The server validates envelopes; it does not observe the events.

My recommendation remains **input-only server authority with 60 Hz gameplay substeps, local prediction/reconciliation, and 20 Hz consolidated replication**, but with a stronger go/no-go gate than my first draft gave it. The c5 critique is right that the current checked-in runtime is not a portable server sim: `craftController.ts` produces forces from Rapier-supplied pad samples, `craftPhysics.ts` performs raycasts and hands integration to Rapier, and the golden contract is same-build local replay only (`AGENTS.md:17-22`; `src/game/craft/craftController.ts:1-5,59-94`; `src/game/craft/craftPhysics.ts:71-206`; `src/game/runtime/determinism/goldenHash.ts:4-19`). A pure authoritative movement core is a new online physics subsystem, not a mechanical extraction.

That is a feasibility and schedule risk, not proof that server authority is incompatible with SpacetimeDB. SpacetimeDB officially supports interval-scheduled reducers and even shows a 50 ms “Game tick”; reducers are transactional/deterministic and therefore require all resumable sim state in tables. A 50 ms transaction can advance three 1/60 s substeps and replicate once; it does not imply 60 reducer transactions or 480 public row updates per second. Current Maincloud performance and cost still must be measured, not assumed. [Schedule tables](https://spacetimedb.com/docs/tables/schedule-tables/), [transactions and atomicity](https://spacetimedb.com/docs/databases/transactions-atomicity/), [table decomposition for 60 Hz state](https://spacetimedb.com/docs/tables/), [Maincloud metering](https://spacetimedb.com/docs/how-to/deploy/maincloud/).

The converged plan should therefore put two gates before schema freeze:

1. Satisfy the captain’s actual P3 exit gate: item-using AI and balance/fairness instrumentation, with eight bots on **both** tracks. The c5 proposal to waive AI item use and freeze on racing bands plus weapon cap tests (`c5/report.md:338`) contradicts the requested checkpoint.
2. Time-box an authority-core/Maincloud spike. Prove handling parity, deterministic replay, racer contacts, both-track surface/fall behavior, 50 ms scheduled cadence/cost, and client correction budgets. If it passes, proceed with input-only server authority. If it fails, stop for an explicit captain re-scope to “experimental client-authority friends lobby”; do not silently ship the c5 trust model under the same multiplayer-v1 claim.

## Where the drafts agree

These parts of c5 should be adopted almost verbatim, subject to the corrections below.

| Area | Agreement and evidence | Converged disposition |
|---|---|---|
| P3 state is behind the brief | AI explicitly emits `fireWeapon: false` and `useUtility: false`; its index says no weapon/item use. The eight-AI suite imports only Neon, while Foundry has line-bot coverage (`src/game/ai/index.ts:1-6`; `driver.ts:351-363`; `raceSim.test.ts:1-16`; `lineBot.test.ts:28-45`). | Treat P3 completion as a prerequisite, not hidden P4 work or a waived gate. |
| N0 is containment, not P4 | N0 has one global race, a client-authored 15 Hz transform relay, monotonic client-reported checkpoints, tokenized respawn, and interpolated non-colliding ghosts (`module/src/index.ts:23-127,471-565,568-622`; `src/net/transformSync.ts:77-200`; `src/game/GhostCraft.tsx:7-31`). Online energy/items/combat are intentionally disabled by `soloLiteralRespawn` (`PlayerCraft.tsx:356-362,396-426`). | Preserve lifecycle semantics and pure rule tests, but do not confuse N0’s presence with transport/combat readiness. |
| Multi-match schema | Replace the singleton race with match-scoped rows; index hot lookups by `match_id`; split public projection from private authority; scope subscriptions rather than `SELECT *` on all rows (`src/net/spacetime.ts:80-101`). | Keep. Use a private room-code mapping instead of putting private codes on a public match row. |
| Generated server data | Expand compiler codegen from Neon-only `trackData.generated.ts` to a two-track registry and generate shared gameplay constants. The 80 vs. 88/105 drift is direct evidence against hand-maintained copies. | Keep. `pnpm track:check`/a companion generated-data check must detect client/module drift. |
| Mandatory compatibility handshake | Every match freezes `compiler_version`, `track_version`, and `gameplay_hash`; every admission compares the client artifact against that match; mismatch grants no participant/input rights and surfaces a clean incompatible-version state. | Keep, but commit an `admission` result row rather than depending on parsing a thrown error. |
| Lobby/ship/lifecycle | Match browser, quick match, join code, lobby-ready flow, both tracks, eight validated visual-only ships, countdown, three laps, results, DNF, 15 s reconnect grace, and rematch are correctly mapped to the existing shell/catalog/lifecycle. | Keep. Fix track switching so existing participants re-ack the new frozen contract, or simpler: lock track at room creation. |
| Combat rules source | Generated damage/caps, server-owned inventory and rolls, `applyHit` ordering, persistent Mine/Rail state, confirmed events, and explicit latency QA are all sound ingredients (`weaponTuning.ts:48-206`; `combatWorld.ts:1013-1159`). | Keep, but run the actual shared combat sim on the authority; do not substitute client hit claims for detection. |
| Testing shape | Pure reducer-equivalent tests, a seeded latency/jitter/reorder harness, accepted-log replay, eight-bot network soaks, version skew, and real Maincloud piloted tests are the right layers. | Keep and add authoritative-vs-predictor hash/correction metrics and Cloud scheduled-tick debt/cost thresholds. |
| Hosting | The draft consistently targets Maincloud and treats a second Cloud database as the dev environment. | Keep. No self-hosting path belongs in the plan of record. |

## Verification of the latent N0 bugs

The draft’s final appendix calls three items “ship-worthy bugs” (`c5/report.md:382-390`). It separately reports a countdown bug. The first two are code-confirmed; the third is a confirmed checked-in configuration mismatch but not proof of the currently deployed Cloud name. The countdown statement is false as written, while the missing server clamp is a genuine hardening gap.

| Claim | Verdict | Evidence and precise consequence |
|---|---|---|
| Server speed cap 80 m/s conflicts with 88 m/s boost / 105 m/s safety cap | **Confirmed current defect.** | `MAX_SPEED_MS = 80` in `module/src/rules.ts:13`, enforced in `rules.ts:405-406` and `module/src/index.ts:506-507`. Client tuning is `TERMINAL_BOOST = 88`, `SAFETY_SPEED_CAP = 105` (`src/game/craft/tuning.ts:141-152`). Online bypasses the solo energy gate and accepts held boost whenever input says so (`PlayerCraft.tsx:411-420`), so a legitimate online body can exceed 80 and have every 15 Hz publish rejected. Generated shared constants are the right immediate N0 fix; input-only authority eventually removes the pose-cap protocol. |
| `reportCheckpointCrossed` hardcodes gates 0–7 while Foundry has ten | **Confirmed latent P4 defect.** | `src/net/raceBridge.ts:4-6` rejects `n > 7`; `src/game/track/tracks/blackRainFoundry.ts:19-28` and its artifact say `checkpointCount: 10`. It does not break today’s online mode because online is forced to Neon, but it blocks the proposed Foundry rollout. Gate count must come from the admitted match/artifact. |
| Client database name `kzero` conflicts with `module-vc9m4` | **Configuration defect confirmed; deployment claim unproven.** | Client hardcodes `.withDatabaseName("kzero")` (`src/net/spacetime.ts:71-75`). The checked-in CLI override says `database: "module-vc9m4"`, while base config says `server: "maincloud"` (`module/spacetime.local.json:1-3`; `module/spacetime.json:1-4`). Official config precedence makes the local file the effective database target for ordinary publish/generate, so these defaults do not point to the same database. However, neither draft queried Maincloud and the CLI is absent, so c5’s phrase “the deployed maincloud DB” is stronger than the evidence. Make URI and DB explicit environment variables and verify the actual Cloud identity during the first deployment smoke. [Official `spacetime.json` precedence](https://spacetimedb.com/docs/cli-reference/spacetime-json/). |
| “Nothing gates driving during countdown” | **Refuted for the honest client; server hardening gap confirmed.** | `RaceController` locks whenever phase is not `racing` (`src/game/race/RaceController.tsx:37-59`). `useInput` passes that lock to the fixed-tick sampler (`src/game/craft/useInput.ts:74-87`), and `sampleCraftInput` returns a fully neutral intent when locked (`inputSampling.ts:220-243`). The c5 evidence log says a grep found no gating (`c5/report.md:378`), but it missed this chain. Separately, `publish_transform` does accept countdown poses (`module/src/index.ts:501-503`; `src/net/transformSync.ts:77-110`), so a modified or buggy client can creep. Add the server grid-radius clamp, but describe it as anti-cheat defense in depth, not a missing normal-client input lock. |

## Netcode disagreement on the merits

### What the current “deterministic sim” does and does not buy

The code has useful authority seams:

- One canonical 60 Hz tick and ordered systems (`src/game/runtime/constants.ts:1-21`).
- Eleven-field quantized input and a ring that repeats sticky hold input but clears the sideshift edge (`src/game/runtime/input/InputIntent.ts:6-32,50-79`; `InputRingBuffer.ts:35-80`). This is already the correct input vocabulary for batching, sequence numbers, prediction, and replay.
- Pure controller force math and a pure, seeded, Rapier-free combat world (`craftController.ts:1-5`; `combatWorld.ts:1-6`).
- Quantized track artifacts with fixed compatibility data and gameplay hashes (`AGENTS.md:25-34`).

It does **not** have a portable authoritative rigid-body world:

- Suspension hits and corner velocity arrive from live Rapier queries; forces/torques are then applied back to a Rapier body (`craftPhysics.ts:71-206,209-225`).
- The solid 2.5 m track slab and hull collision are load-bearing at speed (`AGENTS.md:44-49`).
- The headless eight-AI race is explicitly kinematic and advances track `s`/lateral position with capped rates, not shared craft physics (`raceSim.ts:1-7`; `driver.ts:378-396`).
- The golden hash contains body-ready metadata and optional pose proxies, not a saved Rapier world (`goldenHash.ts:4-19`).

Therefore c5 is right to reject browser-to-browser lockstep and full Rapier rollback for P4. Neither has cross-browser bit stability, full state snapshot/restore, or a recovery path. But those facts do not force client pose authority: the alternative is a deliberately scoped, pure **online** movement/contact integrator shared by server and predictor while solo retains Rapier. That has a feel/parity cost and must pass a spike; it is not blocked by the current same-build-only determinism contract because the new fixed-point core would establish a stronger contract.

### Side-by-side outcome

| Criterion | c5 validated client pose + discrete server mutation | Input-only server authority + prediction |
|---|---|---|
| Local steering latency | Excellent: current Rapier moves immediately. | Also immediate if prediction is implemented correctly. c5’s “full RTT to steering” rejection (`c5/report.md:357`) applies only to unpredicted authority, which neither plan recommends. |
| Reuse / delivery risk | Best short-term reuse of N0 and exact solo craft feel. | High risk: new pure movement/contact core, snapshot/restore, predictor parity, and reconciliation. This is the strongest argument for c5. |
| Driving integrity | Speed/distance envelope only. Client can cut the track, phase through geometry, omit contacts, rotate arbitrarily, or follow an impossible but capped path. | Server computes swept surface, checkpoint, fall, and racer contact from accepted input. |
| Race result integrity | `cross_checkpoint(n)` remains client-authored. Monotonic order and minimum time do not prove spatial crossing (`module/src/rules.ts:449-503`). A client can report every gate on schedule while driving elsewhere. | Checkpoints/laps/finish are consequences of authoritative movement; browser submits no gate. |
| Energy integrity | Server arithmetic depends on client-authored `boosting` and pose. A modified client can report `boosting=false` while moving within the 105 m/s cap, avoiding 120/s drain, or claim strip occupancy within the pose envelope (`c5/report.md:123,145-149`). | Boost, Overdrive, strip occupancy, Nanite, fatal zero crossing all derive from accepted input/state. |
| Projectile integrity | Pulse/Seeker hit truth originates with shooter; Mine truth originates with victim. Fixed damage tables prevent damage-value cheats but not fabricated/omitted hit events. | Persistent projectiles/traps and hit tests advance in the authority tick. |
| Racer contacts | None by default; optional local-only collision is asymmetric (`c5/report.md:96`). The landed live AI field currently has dynamic racers that collide (`AGENTS.md:72-75`). | Simplified but single-authority contact impulses; predictor reconciles confirmed contacts. |
| Network/Cloud load | About 120 client reducer calls and public transform row updates/s at eight racers, plus edge reducers. | At a 50 ms cadence: 160 batched input calls/s, 20 scheduled match transactions/s, and 160 public snapshots/s, plus private state writes. It is more CPU/state, but not the alleged 480 public writes/s. Must be measured on the captain’s subscription. |
| Upgrade path | Not “only pose channel”: combat detection ownership, tick-vs-wall-clock effects, event persistence, checkpoint protocol, energy settlement, and non-colliding ghosts all change in a later authority upgrade. | Establishes the durable authority, replay, and prediction model now. |

### SpacetimeDB constraints do not settle the decision in c5’s favor

The relevant constraints are transactional execution, deterministic reducers, no external I/O, scheduled calls, and no reliance on persistent globals. These require private `sim_match`/`sim_racer` rows and bounded deterministic work; they do not forbid a game loop. Official docs demonstrate 50 ms interval schedules and describe high-frequency `PlayerState` rows. The c5 plan’s claim that Maincloud “bills per reducer execution” and that 60 Hz row writes are “absurd” (`c5/report.md:102,362`) is imprecise: current metering is granular across instructions, bytes scanned/written, index work, storage, and bytes sent. That reinforces the need for a Cloud benchmark, not a categorical rejection. [Maincloud usage breakdown](https://spacetimedb.com/docs/how-to/deploy/maincloud/), [Maincloud pricing dimensions](https://spacetimedb.com/maincloud).

The c5 assertion that Rapier “cannot run inside a SpacetimeDB module” is also not established by the cited repository. What is established is narrower: the module depends only on `spacetimedb`, the root browser depends on `@dimforge/rapier3d-compat`, the CLI is absent, and nested runtime/packaging/determinism on Maincloud has not been proven (`module/package.json:1-8`; root `package.json:30-40`). The converged plan should not depend on Rapier-in-module unless a separate spike proves it. My server-authority recommendation does not depend on it; it uses a plain-data online core.

The c5 statement that N0’s 15 Hz point is “proven fine” (`c5/report.md:180`) is likewise unsupported. `scripts/test.mjs:25-55` runs a pure `module/src/rules.test.ts` two-client lifecycle, not a live SDK/Maincloud latency, fan-out, tab-throttle, or combat soak. The 15 Hz publisher and 120 ms interpolation are implemented; they are not Cloud-qualified (`transformSync.ts:77-200`). Both plans need the same real Maincloud benchmark.

## Refutable or internally inconsistent claims in c5

| c5 claim | Critique | Required correction |
|---|---|---|
| “Server-authoritative outcomes” makes combat fair (`:217-233`) | The server owns arithmetic, not detection. Pulse validation as described checks a travel sphere and bolt count, not the actual bolt corridor against victim history; a malicious shooter can name any victim inside the plausibility volume. Seeker can be claimed once time/distance bounds pass unless the server also simulates the path. | Call this “server-mutated, client-claimed combat” if retained. For P4 proper, advance Pulse/Seeker/Mine in the server tick and publish confirmed events. |
| Victim-triggered Mine is “un-spoofable” (`:228`) | A hacked victim can simply omit `trigger_mine`. The server validates claims it receives but cannot detect a missing claim. It also deliberately drops the landed 7 m pull-field behavior, which currently applies while inside the field (`combatWorld.ts:1499-1540`). | Server detects Mine overlap/pull from authority state. If used as fallback, document it as cooperative-client semantics and do not claim enforcement. |
| M6 can accept 95% true claims and 0% fabricated claims (`:326`) | The proposed plausibility envelope intentionally accepts geometrically plausible client assertions. A fabricated Pulse/Seeker hit constructed inside that envelope is indistinguishable from a true client-simulated one. “0% fabricated” is impossible under the stated validator. | Replace with adversarial tests that demonstrate exactly which fabrications are accepted, or remove claims in favor of server simulation. |
| Server-owned inventory “collapses most combat cheating” (`:256`) | It caps shot count and item provenance, which is valuable, but each valid item can still be converted into a fabricated plausible hit. A victim can omit Mines; client-reported boost can avoid drain. | Keep server inventory as one layer, not the central integrity claim. |
| Reject counters can increment “on validation throws” (`:260`) | Reducers are atomic: a throw rolls back **all** writes. Any `reject_count` increment in the same reducer disappears. [SpacetimeDB atomicity](https://spacetimedb.com/docs/databases/transactions-atomicity/). | For soft/rate rejects, record a reason and return normally; for hard throws, use external reducer-event telemetry or accept that no durable counter is written in that transaction. |
| Reducers “can only signal via thrown errors,” so parse an error prefix (`:167`) | Reducers return no application payload, but subscriptions are explicitly the read path. A normal-return admission transaction can persist `status=incompatible` and expected/received contract fields; a throw cannot persist that state. Parsing transport error text is brittle across SDK/module versions. | Adopt an identity-scoped admission row/event; mismatch commits no participant/input rights and the UI renders the subscribed result. |
| Host can `set_track` and “re-freeze” a live lobby contract (`:141,166,342`) | Existing participants were admitted against the old track. Replacing the match tuple without re-admission violates the handshake invariant even if current bundles happen to contain both tracks. | Lock track at create, or clear ready and require every participant to acknowledge/re-pass the new tuple before countdown. |
| Private lobby means “don’t advertise” while `match.code` is public (`:121`, §4.1) | A modified client can subscribe/query the public match table, including codes, unless row-level security is added. Client-side filtering does not make a code secret. | Put codes in a private `room_secret` table; expose only listed summaries publicly. |
| Event-only Pulse/Seeker telegraphs are sufficient across reconnect (`:128,205,217-231`) | Event rows are not cached. A reconnecting or late subscriber cannot reconstruct in-flight client-owned Pulse/Seeker threats; only Mine/Rail have durable rows. EMP clearing those client-only entities also has no authoritative object set. | Persist all live combat entities or derive them deterministically from authoritative state/history until expiry. Use events for presentation, rows for reconstructable threats. |
| Arc rows are always ≤66 ms stale and extrapolation error ≤1–2 m (`:227`) | 15 Hz is nominal publish cadence, not a staleness guarantee; reducer/SDK delay, throttling, rejects, or disconnects can make a row older. At 105 m/s, 66 ms is 6.9 m of travel before any acceleration/turn error. Velocity extrapolation helps constant motion but does not establish the claimed bound. | Store bounded authoritative pose history and define a maximum rewind/extrapolation window; reject/ignore older targets or degrade explicitly. Test actual error distributions. |
| Rail gives ≥400 ms dodge time at 200 ms RTT (`:230`) | Half-RTT delivery would nominally leave ~550 ms, but scheduler/commit/subscription jitter and client clock estimation are unmeasured. A fixed future timestamp ensures common server resolution, not the claimed minimum local warning. | Make “positive telegraph lead at supported RTT” a measured launch metric, not a guaranteed arithmetic assertion. |
| “Everything inside the fork already exists; re-plumbing, not new mechanics” (`:286`) | Online currently disables the entire P2 block. c5 proposes a second time-based combat/energy implementation, three ownership classes, a new bridge, claim protocols, lazy settlement, new respawn arbitration, and deliberate Mine semantic divergence. This is substantial new mechanics/network code. | Size milestones and review risk accordingly; share pure tick rules rather than porting them to ad hoc timestamp formulas where possible. |
| P3 freeze may omit AI item use (`:338`) | The captain explicitly required the both-track eight-bot balance/fairness exit gate before schema freeze, and the task premise names AI item use. Current code disproves the premise but does not authorize weakening the gate. | Add/finish item-using AI and both-track fairness instrumentation before P4 schema freeze, or obtain an explicit captain re-scope. |

## What the converged plan should adopt from each draft

### Keep from x9 (server-authority draft)

1. **Authority boundary:** browsers submit only quantized input frames; the server owns movement, contacts, gates, pickups, energy, combat detection, finish, and results. No client pose/checkpoint/pickup/hit reducer survives the migration.
2. **Cadence split:** 60 Hz gameplay substeps inside one scheduled transaction every 50 ms, with one 20 Hz public snapshot. This preserves tick-defined weapon/energy constants without 60 public replications/s. Treat cadence, tick debt, CPU instructions, bytes written/sent, and cost as measured gates.
3. **Prediction/reconciliation:** retain unacknowledged input/state history; restore at acknowledged tick, replay, smooth small corrections, and snap only for lifecycle/large errors. Remote racers interpolate authoritative snapshots. This answers c5’s legitimate input-latency concern.
4. **Shared fixed-point online core:** pure numeric movement/contact and landed energy/items/combat rules compiled into both module and browser predictor. Solo remains on Rapier. Persist all authority state in private rows because reducer globals are not durable.
5. **No client claims:** persistent Pulse/Seeker/Mine/Rail entities; swept substep tests; current-state Rail/EMP; bounded pose-history compensation only for truly instant Arc. Confirmed events drive hit markers/VFX.
6. **Private admission/result architecture:** identity-scoped admission row, private room codes, input rows, sim rows, pose history, immutable results, and event sequence numbers.

### Keep from c5 (validated-client draft)

1. **Ground-truth audit and generated constants:** especially the speed-cap drift, ten-gate bridge issue, Neon-only module registry, online P2 containment, and two-track codegen requirements.
2. **Lifecycle decomposition:** multi-match N0 semantics, explicit leave, janitor, rejoin grace, ship changes before ready, both-track scene remount, and concrete UI shell states.
3. **Weapon-specific latency reasoning:** preserve the useful distinction between travel-time entities, instant volumes, persistent traps, and telegraphed future resolves. Apply that distinction inside server authority: Pulse/Seeker/Mine simulate continuously; Arc uses capped history; Rail stores its fire corridor and resolves at the authority tick; EMP uses current authority state; countermeasure activation order is a server-tick rule.
4. **Optimistic presentation:** immediate local muzzle, utility activation, pad-darken, and predicted HUD/VFX are fine so long as damage, item ownership, energy, and hit markers reconcile to authority.
5. **Testing/QA detail:** pure reducer mirrors, deterministic event-queue latency harness, accepted-input replay hash, both-track eight-bot soaks, version-skew UI tests, and real Maincloud browser sessions under throttling.
6. **Environment/deploy hygiene:** `VITE_STDB_URI` plus `VITE_STDB_DB`, generated bindings in a CLI-equipped environment, a Cloud dev database, and module/client built from the same commit.

## Recommended converged milestone order

This is the minimum change to the original x9 sequence needed after reading c5.

| PR | Scope | Acceptance gate |
|---|---|---|
| P3-exit | Land/verify AI item and utility use, balance aggregation, and eight-bot balance/fairness suites on Neon and Foundry; include grid/ship neutrality and combat distribution, not only lap bands. | Both tracks × eight bots pass deterministic completion, fairness, item-use, caps, and distribution thresholds; captain signs the report. **No P4 schema freeze before this.** |
| P4-0 authority feasibility | Test-only/shared prototype of pure online movement/contact core and predictor; isolated Maincloud schedule at 50 ms; both tracks, eight racers, high-speed slab/crest/wall/contact cases. Do not depend on Rapier-in-module. | Deterministic hash parity; handling metrics and piloted A/B accepted; no fall-through/softlock; correction budgets through 150 ms RTT; scheduled callback/tick-debt/energy/bandwidth budgets pass. Failure stops for explicit re-scope. |
| P4-1 generated contract + admission | Two-track server registry and tuning generation, drift guards, multi-match base schema, admission row, private codes, environment DB name, handshake UI. Fix N0 speed/gate/config defects on the compatibility path. | Wrong compiler/hash/protocol commits `incompatible`, creates no participant, and clean UI renders it; both-track registry exact; real Maincloud two-browser smoke. |
| P4-2 rooms/lobby/ships/lifecycle | Browser/quick/code, eight ship IDs, ready/countdown, both tracks, DNF/rejoin/rematch/janitor. Lock track at create or require new contract acknowledgement. | Two-to-eight-client lifecycle matrix on Cloud; all ship assets/track gates correct; private codes not queryable from public lobby data. |
| P4-3 input/tick/state authority | Input batches, scheduled substeps, private sim rows, authoritative progress/contact/fall, public snapshots, metrics. N0 protocol remains behind a temporary flag only. | Browser sends no pose/gate; server completes both tracks; contacts and results deterministic; disconnect neutral timeout; Cloud budgets pass. |
| P4-4 predictor/remotes | Local snapshot restore/replay/smoothing, remote interpolation, selected ship meshes, correction overlay. Remove N0 pose/checkpoint reducers after gate. | Correction/snap thresholds at supported latency; zero local steering delay; remote extrapolation bounded; close-pack piloted QA passes. |
| P4-5 energy/items | Shared tick rules for boost, strips, fatal boost, utilities that affect energy, pickup rolls/contested sockets/absorb. | No client-authored boost flag/pose claim affects authority; exact tick replay; contested first authority tick wins; UI prediction reconciles. |
| P4-6 combat core + instant/telegraph weapons | Shared `applyHit`, Arc bounded history, Rail charge/current resolve, EMP, Aegis/Specter/Overdrive/Nanite, destruction/respawn. | Caps/counter windows identical to solo rules; telegraph lead measured at 50–250 ms RTT; reconstructable after rejoin. |
| P4-7 travel/trap combat | Persistent Pulse, Seeker, Mine simulation and events. | No shooter/victim claims; swept hit tests; Mine pull/core exact; Seeker/Specter order deterministic; no orphan/double entities in soaks. |
| P4-8 release | Anti-cheat protocol/rate limits, durable soft-reject telemetry, result audit, janitor, docs, prod Cloud wiring and flag flip. | Version-skew, adversarial protocol, 30-seed both-track network soak, and piloted four/eight-player Maincloud sign-off. |

## Open questions / residual risks

1. **Authority-core feel is the decisive risk.** The code does not yet contain a server-ready replacement for Rapier suspension/slab/hull contacts. The spike needs explicit pass/fail thresholds; “simplified” cannot mean a different-feeling racer hidden behind network work.
2. **Maincloud cadence and energy are unknown.** Official capability is not an SLA. Measure p50/p95/p99 scheduled lateness, callback duration, tick debt, instructions, table work, and fan-out on the captain’s actual subscription and target region.
3. **TypeScript module dependency support is unproven.** Do not state Rapier is impossible, but do not plan on it. If the pure core fails parity, a narrow Rapier packaging/determinism Cloud spike is a possible decision input, not the default architecture.
4. **Schema migration/versioning needs a concrete publish strategy.** The current singleton tables and checked-in bindings are N0. Decide whether the Cloud dev DB can be recreated during P4 and which production data must be migrated before freezing table names/types.
5. **Counterplay at high latency needs metrics, not duration arithmetic.** Rail, Mine, Seeker lock/Specter, Aegis, and EMP should report event-to-visible warning lead and input-to-authority activation across the supported RTT/jitter matrix.
6. **Identity is browser-token-only in v1.** That is proportionate for friends lobbies, but it makes bans/reputation disposable. Keep enforcement match-scoped and do not imply account-grade anti-cheat.
7. **If the authority spike fails, c5 is a viable fallback only after re-scope.** Label it experimental/casual, make remote craft non-colliding, mark results unranked, state client movement and hit-claim trust plainly, remove the impossible “0% fabricated” gate, and choose whether reduced Mine/Pulse/Seeker semantics are acceptable.

## Evidence log

Commands run during this cross-review (abridged):

```text
wc -l -w -c /Users/leebarry/firstmate/data/kz-p4-plan-c5/report.md
sed -n '1,179p' .../kz-p4-plan-c5/report.md
sed -n '180,300p' .../kz-p4-plan-c5/report.md
sed -n '301,390p' .../kz-p4-plan-c5/report.md

rg -n "MAX_SPEED_MS|TERMINAL_BOOST|SAFETY_SPEED_CAP" module/src src/game/craft
rg -n "reportCheckpointCrossed|n > 7|checkpoints: 10" src/net src/game/track
rg -n "withDatabaseName|module-vc9m4" src/net module/spacetime*.json
rg -n "setInputLocked|isInputLocked|countdown" src/game/race src/game/craft src/net module/src

sed/nl reads of:
  module/src/{index,rules,rules.test}.ts
  src/net/{spacetime,transformSync,raceBridge,matchAdapter}.ts
  src/game/runtime/{constants,GameRuntime}.ts and runtime/input/*
  src/game/craft/{craftController,craftPhysics,inputSampling,useInput,PlayerCraft}.ts(x)
  src/game/weapons/{weaponTuning,combatWorld}.ts
  src/game/ai/{driver,raceSim,raceSim.test}.ts
  src/game/track/tracks/blackRainFoundry.ts
  AGENTS.md, module/{package,spacetime,spacetime.local}.json, scripts/test.mjs

command -v spacetime
# no output: CLI unavailable, so no module build/publish/live database query was performed
```

External documentation checked because SpacetimeDB behavior and Maincloud metering are version-sensitive:

- [Schedule tables](https://spacetimedb.com/docs/tables/schedule-tables/) — interval schedules, including a 50 ms game-tick example.
- [Transactions and atomicity](https://spacetimedb.com/docs/databases/transactions-atomicity/) — a thrown reducer rolls back all writes.
- [Tables](https://spacetimedb.com/docs/tables/) — high-frequency `PlayerState` decomposition and 60 Hz position-update example.
- [`spacetime.json` configuration](https://spacetimedb.com/docs/cli-reference/spacetime-json/) — local override precedence and database selection.
- [Maincloud](https://spacetimedb.com/docs/how-to/deploy/maincloud/) and [pricing](https://spacetimedb.com/maincloud) — managed Cloud target and granular energy/usage dimensions.

## Final recommendation

Adopt c5’s audit, generated-data discipline, multi-match/lobby design, latency test harness, and weapon-specific presentation policy. Do **not** adopt its client hit claims, victim Mine reports, client boost settlement, client checkpoint results, non-colliding default, thrown-error telemetry, or waived P3 gate as the definition of P4 multiplayer v1.

Proceed only after the P3 exit and authority-core/Maincloud gates. If those pass, ship the x9 input-only server authority with prediction and c5’s stronger lifecycle/QA details. If they fail, return to the captain with a clearly named experimental N0 extension as the fallback; the trust downgrade is a product decision, not an implementation detail.
