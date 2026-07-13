# K-ZERO implementation-plan cross-review

**Reviewer:** plan-sol-w2  
**Compared draft:** `/Users/leebarry/firstmate/data/plan-fable-r7/report.md`  
**Baseline draft:** `/Users/leebarry/firstmate/data/plan-sol-w2/report.md`  
**Live-code findings:** `/Users/leebarry/firstmate/data/kzero-review-findings.md`  
**Date:** 2026-07-13

## Executive verdict

The drafts agree on the important product strategy: no full ECS, one ordered fixed simulation, dynamic Rapier hover bodies, shared boost/health energy, spline-authored tracks, offline feel before combat/AI/networking, server-owned race/combat rules with explicitly casual client-owned movement, and evidence-based AAA/QA gates. That agreement is strong enough to converge without a new architecture spike.

The independent Fable draft is strongest when it is concrete about **what makes an anti-gravity racer distinct**: airbrakes/sideshift, item absorption, distance-aware item odds, a lateral-offset racing-line representation, bounded time-gap rubber-banding, a three-band engine sound, and cheap optic-flow scenery. Those ideas should be imported.

Its largest weakness is that its baseline calls the current SpacetimeDB multiplayer “working” and repeatedly treats existing reducers as integrated features. The live findings prove otherwise: checkpoint reports have no caller, client-declared respawn is a teleport bypass, local and server race clocks conflict, the finished lobby is a UI dead end, and racing disconnects have no completion policy. That is not a wording issue; it changes the roadmap entry gate and invalidates several “already exists” assumptions.

The Sol draft is more conservative and coherent on match scoping, server authority, exact death-pose preservation, production budgets, second-track ordering, and release proof. It also has a real inconsistency to remove: §1 specifies a 60 Hz simulation while its audit ledger accidentally says 120 Hz. The converged plan should choose **60 Hz**, measure it, and treat 120 Hz only as a failed-acceptance fallback experiment.

The recommended synthesis is therefore: use Sol's architecture/roadmap spine, import Fable's handling, AI, audio, and item-economy details, add an immediate multiplayer containment/integration gate for all five live findings, and narrow online v1 to human-only casual rooms.

---

## 1. Strongest ideas to adopt from the Fable draft

### 1.1 Make anti-gravity handling more than “car steering without wheels”

Fable's Q/E airbrake and sideshift proposal is the clearest missing handling verb in the Sol draft. A WipEout/F-Zero-inspired racer benefits from a separate line-tightening control and an intentional lateral dodge; steering, drift, and boost alone risk feeling like an ordinary arcade car with a hover shader.

Adopt the concepts, with two constraints:

- Holding left/right airbrake adds side-specific drag and bounded yaw assistance; it must not directly set angular velocity.
- A double-tap or separately bindable action performs a short lateral impulse with a cooldown. The binding must be remappable because double-tap timing is an accessibility and keyboard-reliability risk.

Do **not** import Fable's unconditional `+9 m/s` drift-release mini-turbo. Shared energy already supplies the speed economy, and a free impulse invites the same snaking exploit both drafts say they want to prevent. Sol's bounded conversion of shed lateral energy is safer: a good drift should lose less speed or recover a small fraction of real dissipated energy, never create energy from alternating inputs.

### 1.2 Use explicit lateral-offset racing lines and target-speed arrays

Fable specifies a useful authoring/runtime representation: one lateral offset and target speed per compiled track sample, produced offline and checked into content. This is more actionable than merely saying “AI follows a spline.” It supports:

- the same spatial lookup used by progress and minimap;
- debug visualization of desired line and braking envelope;
- per-track bot acceptance bands;
- controlled overtake offsets without recomputing splines at runtime.

Adopt it into Sol's `TrackCompiler` outputs. The generator should be deterministic, validate `abs(offset) <= width/2 - craftMargin`, and run a backward braking pass. Designers may override sections, because a pure curvature-minimizing line will otherwise ignore energy pits, pickups, hazards, and tactical combat lanes.

### 1.3 Rubber-band by bounded driving skill, not hidden vehicle power

Fable's signed time-gap controller with a dead zone is a good concrete implementation of the principle both drafts share. Adopt:

- gap measured in **seconds**, not meters, so the rule transfers across tracks and speed zones;
- no adjustment within roughly ±0.4 s of the reference player;
- line accuracy, reaction delay, braking conservatism, and boost reserve as the first tuning levers;
- a hard pace multiplier ceiling of 1.03 and floor appropriate to the tier;
- the director disabled in time trial, the highest difficulty, and any future ranked mode.

The target must be the field/leader envelope, not always the local human, or multiple humans and split packs will produce contradictory corrections.

### 1.4 Add “absorb held weapon for energy” to the shared-energy economy

Fable's WipEout-style absorb mechanic turns every weapon pickup into a fire-versus-survive decision and helps a player recover without adding a separate repair economy. It fits the shared boost/health resource better than a proliferation of repair items.

Adopt it only for the **weapon slot**: hold the weapon action for 0.6 s to convert it to a catalog-defined energy amount, interrupted by taking damage. Keep Sol's separate utility slot so shield/spoof counterplay is available when an attack is telegraphed. This produces a clear two-slot HUD and avoids the Fable draft's problem where a player must randomly possess the one defensive answer at the instant a seeker arrives.

### 1.5 Make item odds depend on race gap, not just ordinal position

Fable correctly recognizes that “last place” means different things when the field is separated by 20 m versus 500 m. Adopt gap-sensitive weighting, but normalize it to leader time gap rather than fixed track meters. Combine it with Sol's authored row families:

1. The row's family defines the legal category set (`offense`, `defense`, `utility`, `wildcard`).
2. Server-owned time gap modifies category weights.
3. Rarity selects within the category.

This preserves track-route intent while avoiding an invisible guaranteed comeback weapon. The exact tables belong in data and must sum to 100 in tests.

### 1.6 Import the audio architecture, not its unsupported music fallback

Fable's three cross-faded engine bands, boost layer, nearest-remote voice cap, small pitch randomization, and mix priority are concrete and worth adopting. They provide the vehicle-specific sound pillar identified in the research while controlling browser audio cost.

Do not adopt the suggestion to use a 30-second ElevenLabs loop as “interim music” after correctly noting that the installed audio generator has no music endpoint. Music should be CC0/CC-BY with verified attribution, commissioned, or explicitly temporary developer-only material. Ambience is not a substitute for a race score.

### 1.7 Keep the cheap speed-readability ideas

Fable's near-track pylons, overhead gantry rhythm, large horizon anchors, curvature-driven chevrons, and strong track/background hue separation are high-value. Adopt them into both launch tracks as compiler-assisted decoration sockets. These cues are more reliable and cheaper than adding blur. Sol's rejection of motion blur and post-processing budget remains the governing rule.

### 1.8 Reuse the AI driver as a QA bot from the first playable phase

Fable makes the AI intent driver double as the CI playtest bot and adds measurable lap-time, softlock, difficulty, and combat-soak outputs. Sol has the same end-state but schedules the full harness late. The converged roadmap should add the deterministic hook and a simple line bot in Phase 1, then extend it as AI/combat land. P6 remains the release hardening pass, not the first appearance of automation.

---

## 2. Concrete disagreements with the Fable draft

### 2.1 The current multiplayer is not “working”

Fable's executive summary calls the current implementation “working SpacetimeDB multiplayer” with “server-authoritative checkpoints/laps,” and its inventory says there is “disconnect cleanup.” The live findings contradict both claims:

- `reportCheckpointCrossed()` has no caller, so the server's valid `cross_checkpoint` reducer never advances a live racer.
- A racing disconnect leaves an unfinished participant until the five-minute timeout; that is not a complete disconnect policy.

The reducer existing is not evidence that the feature works end to end. The converged baseline must say “network prototype with unintegrated/broken race lifecycle,” and multiplayer UI should be feature-gated as experimental until the containment work in §4 below is complete.

### 2.2 Client-authoritative movement cannot mean “nothing to reconcile”

Fable says the own craft has nothing to reconcile because the server never overrides movement. That is internally consistent but misleading: it is not prediction/reconciliation; it is untrusted client authority with accept/reject plausibility rails. A rejected transform needs a deterministic recovery path to the last accepted state, and the current `respawn: true` escape hatch defeats those rails entirely.

Resolution:

- Call the model **client movement authority with server validation**, not server reconciliation.
- Publish monotonic sequence numbers plus bounded input summaries and pose/velocity/progress.
- The server retains the last accepted state and returns explicit rejection/discontinuity events.
- The client hard-resets or short-blends to that last accepted state based on error/contact context.
- There is no continuous rollback/replay until a server sim produces authoritative poses.

This remains casual and must be labeled as such. Sol's input buffer is useful for diagnostics and rejection recovery, but its language should also avoid implying a real authoritative movement state that the server cannot compute.

### 2.3 Do not make host-simulated AI part of online v1

Fable proposes that the first participant simulates online AI and sketches host migration. That is a second authority system layered onto an already compromised client-movement model. It adds host cheating, disconnect migration, divergent projectile interactions, and race-result ownership for little launch value.

Online v1 should be **2-8 humans only**. Offline AI is the content and QA path. Network AI can return only after either a dedicated authority service or a well-scoped server-compatible craft solver exists. Sol's “optional AI fill” wording should also be removed from v1 so this decision is unambiguous.

### 2.4 Match scoping is not a post-v1 luxury

Fable keeps the single global room through a middle stage and defers named rooms. A single global table cache and `SELECT *` subscriptions are tolerable for a developer prototype, not for a public multiplayer release. Match/lobby scoping is also needed to test cleanup, privacy, and multiple concurrent matches.

Adopt Sol's P4.1 schema split and scoped subscriptions before any claim of playable online combat. v1 can still be small: coded rooms plus quick-join, no rating, parties, persistence, or regional matchmaker.

### 2.5 Do not copy a hand-maintained server track sample table

Fable's track-space combat proposal bakes a ~30 KB track table separately into the SpacetimeDB module. A duplicate manually maintained artifact will drift from the client geometry and create false checkpoint/hit validation.

The compiler should emit one versioned, hashed, quantized gameplay artifact containing center, frame, width, gates, safe poses, and spatial cells. Both the client build and server module consume generated output from that artifact. The match row stores its version/hash and refuses clients with a mismatch.

### 2.6 Pure two-dimensional track-space combat is insufficient

Fable's `s + lateral` server combat is elegant for Quake waves and simple seekers, but it breaks at flyovers, jumps, high banking, tunnels, line-of-sight occlusion, and any future split path. Conversely, simulating every projectile as full Rapier server physics is out of scope.

Use a hybrid authoritative rule set:

- Quake, track traps, pickup proximity, and broad area effects use quantized track coordinates `(segment, s, lateral, height)`.
- Pulse/Rail use a capped server-rewound 3D segment/corridor against accepted racer transforms and a coarse generated occluder set.
- Seekers are server-owned parametric entities with track-segment identity and a height band; clients only predict presentation.
- No shooter- or victim-declared hit becomes authoritative.

This keeps server rules cheap while respecting the actual 3D track.

### 2.7 Preserve the literal kill pose

Fable captures a death location and then projects it to the nearest track cross-section before respawn. The brief says destroyed racers respawn “at the location where they were killed.” Projection can move the craft several meters, especially near a wall, jump, or overpass.

Adopt Sol's literal `deathPose` rule: position and quaternion are restored exactly at the logical one-second deadline with zero velocity, racer/weapon collision ghosting, and damage grace. Falling off the course without opponent kill credit is a separate safe-frame recovery rule. If an opponent kills a racer over a void, the holographic respawn still appears at the kill pose; normal physics may then produce a fall recovery. This is literal, testable, and avoids hidden relocation.

### 2.8 A 20 Hz scheduled reducer cannot by itself guarantee wall-clock execution at exactly 1.000 seconds

Both drafts overstate scheduled-reducer precision. SpacetimeDB schedules express the authoritative deadline, but execution and subscription delivery may be slightly late. “Exactly one second” must be defined as a **logical state transition time**, not guaranteed packet arrival:

- On death, transactionally write `deathPose` and `respawnAt = deathAt + 1,000,000 μs`.
- All reducers and queries treat the racer as alive/grace once authoritative time reaches `respawnAt`, even if the cleanup/materialization reducer runs late.
- Schedule a reducer for prompt row materialization, and also lazily materialize overdue transitions on the next relevant reducer.
- Clients clock-sync and present reconstruction at `respawnAt`; a later contradictory server result reconciles, but the ordinary path is deadline-driven.
- Test logical timestamp equality separately from network presentation latency.

Offline remains exactly tick +60.

### 2.9 Upgrade track frames now, but not with `computeFrenetFrames`

Fable recommends retaining `tangent × worldUp` for launch and deferring rotation-minimizing frames. That minimizes near-term change, but the frame is a foundational artifact used by surface geometry, suspension, AI, pickups, respawn, minimap, and server validation. Replacing it after two tracks and multiplayer serialization is more expensive and riskier.

Adopt Sol's custom parallel-transport/RMF compiler in P1.2, plus Fable's important caveat: authored bank is an additional roll around tangent, and Three.js `computeFrenetFrames` is not the implementation. Validate orthonormality, closed-loop seam twist, grade, clearance, and frame continuity with golden fixtures. Keep the current world-up builder only as a comparison/debug fallback during migration.

### 2.10 Second-track content should precede multiplayer

Fable puts its second track in the late content phase after multiplayer combat. That allows networking code to bake in assumptions from one course and postpones proof that compiler, spatial coordinates, AI, pickups, rendering, and match track hashes are genuinely data-driven.

Keep Sol's ordering: second greybox/art track after AI and offline combat, before multiplayer. Retain **Black Rain Foundry** as the visual contrast to Neon Orbital; import Fable's best Vector Sunset encounter beats—a long duel straight, tunnel contrast beat, crest/jump, and pickup-line chicane—into Foundry's industrial/rain setting. Neon Orbital already covers the clean cyan/magenta synthwave register, so a second sunset synthwave track would add less portfolio breadth.

### 2.11 Use credential evidence, not aspirational generator commands

Fable specifies a Tripo hero command and generated audio/images but does not include the required literal credential probe. The verified probe in Sol is:

```text
TRIPO_API_KEY=MISSING
GEMINI_API_KEY=MISSING
ELEVENLABS_API_KEY=MISSING
```

Therefore generated production assets cannot be a guaranteed critical-path acceptance criterion today. The synthesis should keep the per-surface generation route, but make it conditional on credentials. CC0/kitbash/blockout work proceeds; the hero-ship gate is either satisfied by configured generation plus technical-art cleanup, a manually authored/commissioned asset, or explicitly remains blocked. Grok `/imagine` is a planned sourcing route from the brief, not interchangeable with an unavailable Gemini key.

### 2.12 Reconcile the performance budgets instead of choosing incompatible totals

Fable uses the skill's generic ≤300 calls/≤750k triangles/≤256 MB texture targets. Sol uses a stricter ≤180 calls but allows ≤1.2M triangles and separately caps total browser memory at 512 MB. The categories are not directly comparable.

Use one launch Tier-A budget:

- ≤180 draw calls in worst active race view;
- ≤900k visible triangles, with a measured exception up to 1.2M only when GPU time remains inside budget;
- ≤256 MB estimated decoded GPU textures and ≤512 MB total browser process memory;
- post-processing ≤2.0 ms GPU;
- physics + simulation + AI ≤4.0 ms CPU at eight racers;
- 60 fps median and ≥55 fps 1% low over the prescribed stress capture on the target device.

Headless tests may assert counts, never FPS. Adaptive quality degrades shadows/post/DPR/particles before road, telegraphs, HUD, or collision behavior.

### 2.13 Settle the physics rate at 60 Hz

Fable consistently chooses 60 Hz. Sol §1 also chooses 60 Hz, but its late audit ledger accidentally says 120 Hz. The synthesis should remove that contradiction.

Use fixed 60 Hz because it matches the current project, makes exact offline respawn 60 ticks, and keeps 8×4 suspension rays plus AI/combat within the browser CPU budget. Instrument missed steps and suspension error. Only test 120 Hz in an isolated spike if the 60 Hz implementation cannot pass crest, CCD, or hover-stability acceptance after force/filter tuning; do not put a speculative 2× physics cost on the critical path.

### 2.14 Narrow launch devices honestly

Fable says mobile is out of scope, while Sol plans Tier-B and narrow HUD checks but lists full mobile parity as a non-goal. Converge on: desktop browsers with keyboard and common gamepads are launch targets; responsive/narrow UI and reduced-quality rendering are tested, but touch controls and mobile gameplay are not a v1 promise. This avoids shipping an “AAA” claim on devices that have no input or thermal acceptance plan.

---

## 3. Gaps both drafts missed or under-specified

### 3.1 All five live multiplayer findings need explicit entry-gate resolutions

Both drafts discuss some symptoms, but neither turns the full findings document into a concrete containment PR before later multiplayer work.

| Live finding | Why current plans are insufficient | Required resolution |
| --- | --- | --- |
| Client-controlled `respawn` bypasses delta validation | Both ultimately propose server respawn, but leaving the current flag usable until Phase 4 keeps a live teleport vector. | Immediately reject client-declared discontinuities unless they match a one-time server-issued token/pose; until then feature-gate public multiplayer. Server death/fall/grid reducers alone mint discontinuities. Movement limits use server elapsed time, not client cadence. |
| `reportCheckpointCrossed()` has no callers | Both describe authoritative gates as if wired. | Add the Track sensor → net adapter call, monotonic gate sequence/idempotency, online-mode guard, and a two-client integration test proving three laps finish. Do not infer completion from reducer unit tests. |
| Local race auto-start conflicts with lobby phase | Sol says retire competing phases later; Fable largely treats both as working. | Choose one mode at boot. Offline `LocalMatchAdapter` may drive countdown/laps; online `SpacetimeMatchAdapter` is the sole phase/clock authority. `RaceController` cannot auto-start in online mode. |
| Finished lobby is a dead end | “Race again” is mentioned but no state contract is specified. | Add `request_rematch` valid only in `finished`; reset connected members' ready/result state transactionally and return to track vote/lobby when all connected racers request or the host confirms after a short results lock. If host left, elect the lowest connected slot. Never render a Ready action the reducer rejects. |
| Disconnect can hold race open five minutes | Generic “disconnect/reconnect tests” do not define behavior. | Lobby/countdown: clear ready; cancel countdown if connected racers <2. Racing: mark disconnected/non-colliding, reserve slot for 15 s, then DNF; all-finished logic treats DNF as terminal. Reconnect inside grace restores the craft, after grace joins results/spectate. Scheduled respawn can occur during grace but does not prevent later DNF. |

This should be a small **N0 network containment/integration PR** after the separate live handling/visibility fix and before the game advertises multiplayer. The full schema rewrite still belongs in Phase 4.

### 3.2 Offline and online pause semantics are undefined

The menu/HUD sections list pause, but neither draft states that an online race cannot pause the authoritative clock. Resolve:

- Offline pause freezes fixed simulation, audio envelopes, race clock, AI, and timers.
- Online “pause” is an input-neutral settings overlay; the race continues, with a prominent LIVE indicator and automatic throttle release.
- Tab blur/controller disconnect clears input in both modes; online it does not suspend network publication/reconnect handling.

Add browser tests for focus loss in countdown, racing, destroyed, and results states.

### 3.3 The control surface needs onboarding

The converged controls include steering, throttle/brake, drift, two airbrakes/sideshift, boost/energy, weapon fire/absorb, and utility. Neither plan allocates an onboarding path. A “stranger can finish three laps” gate is unlikely without one.

Add a skippable 60-90 second first-run training overlay/time-trial sequence on Neon Orbital: accelerate/steer, energy boost/pit, drift/airbrake, pickup/fire, utility/lock, then one full lap. Detect input device and show the real binding. The tutorial is data-driven and disabled for repeat runs. It is a Phase 1 UI/content task, not a career mode.

### 3.4 Server abuse limits and event retention are not concrete enough

Casual authority still needs denial-of-service and table-growth protection. Add per-identity reducer rate limits/payload bounds, monotonic sequence windows, maximum live projectiles/mines, event TTL/cleanup, match row expiry, maximum rooms per identity/IP-equivalent where available, and structured rejection counters. Avoid logging raw anonymous tokens or excessive movement history. Include a malicious-client soak, not just latency/loss.

### 3.5 Position-weighted loot depends on untrusted movement

Both drafts make item distribution depend on position/gap while movement remains client-authoritative. A cheater could claim slow progress to roll catch-up items, then teleport within plausibility bounds. Calculate the bucket from server-owned lap/gate plus bounded progress derived from the last accepted generated track coordinate; cap bucket changes per unit server time and never accept client-supplied rank. This does not make v1 secure, but it closes an obvious economy exploit.

### 3.6 Exact respawn needs a clock-fault policy

Neither draft covers large clock-offset changes, a suspended browser tab, or a reconnect that crosses `respawnAt`. The server row is authoritative: on subscription/reconnect, derive current state from server time and transition directly to alive/grace if the deadline passed; never replay a stale one-second local animation before accepting input. Clock sync uses a monotonic median and snaps only on large discontinuities with telemetry.

### 3.7 Generated gameplay artifacts need schema/version migration

Both plans mention hashes, but the compiler output needs an explicit compatibility contract. Store `{compilerVersion, trackId, trackVersion, gameplayHash, artVersion}`. Gameplay hash changes invalidate replays, AI line files, server validation samples, and active matches; art-only changes do not. CI regenerates and fails on dirty output. Old match/replay handling must show “incompatible version” rather than silently loading different geometry.

### 3.8 Accessibility needs a photosensitivity gate, not only reduced motion

Both drafts mention reduced motion/color modes, but the proposed neon flicker, scanline, chromatic pulses, damage flashes, and lightning effects need a flash policy. Add:

- no persistent full-field flicker;
- frequency/luminance-area caps for bright flashes;
- “reduced flashes” separate from camera reduced motion;
- non-color telegraphs for locks, pickups, damage, and track edges;
- visual captions/icons for critical audio cues.

Include these states in visual regression and manual QA.

### 3.9 Research-tool compliance remains incomplete

The brief explicitly required both Exa and Ref technical documentation search. Fable substitutes Context7 and official fetches; Sol could call Ref manuals but reports that the technical search/read calls were not exposed, then also used official docs. Both are transparent, but neither actually fulfilled the requested Ref technical-search evidence. The synthesis must not imply otherwise. It should preserve the limitation in the evidence ledger and, if a later runner exposes Ref search, run the missing R3F/Rapier/Three.js/SpacetimeDB/postprocessing queries before implementation approval.

### 3.10 Mode scope should be explicit

The launch game should contain offline time trial, offline eight-racer combat circuit, and online human combat circuit. Do not imply a separate elimination arena, battle mode, ranked mode, split screen, career, or persistent leaderboard. Both drafts imply this but never state one canonical mode matrix, leaving room for scope creep.

---

## 4. Recommended resolution per major architectural/design decision

| Decision | Recommended resolution | Why / rejected alternative |
| --- | --- | --- |
| Core architecture | Plain data-oriented `GameRuntime` with stable IDs, packed stores, ordered systems; no ECS. R3F/React are views/lifecycle; low-rate external UI store. | Both drafts agree. Reject full ECS and 60 Hz React state because entity count is small and hot-loop allocations/reconciliation are avoidable. |
| Physics integration | One Rapier world, dynamic craft bodies, central pre/post step orchestration at fixed 60 Hz. Pure craft math consumes state/input/probe results and returns force commands; a Rapier adapter owns queries/handles. | Preserves physical collision response and testability without pretending WASM handles are pure data. Reject kinematic craft and a second RAF loop. |
| Determinism | Same-build local repeatability only: integer ticks, seeded RNG, stable ordering, quantized inputs, simulation-version hash. | Useful for QA/replays; reject cross-client lockstep/rollback claims. |
| Track frames | Custom rotation-minimizing parallel transport now, closed-loop seam correction, authored bank as roll; compiler emits one hashed shared gameplay artifact. | More durable than world-up once track frames feed physics/networking. Reject Three Frenet frames and duplicated server tables. |
| Launch tracks | Neon Orbital upgraded first; Black Rain Foundry second before multiplayer. Give Foundry a long duel straight, tunnel, crest/jump, pickup chicane, rain/industrial skyline. | Stronger visual/gameplay contrast than two synthwave tracks; proves multi-track data contracts before network schema freezes. |
| Vehicle envelope | Start P1 tuning at 70 m/s normal, 88 m/s boost, 105 m/s safety cap; fictional league display uses one named conversion constant. Final values move only through handling metrics/playtest. | Splits Fable's conservative 58/76 and Sol's aggressive 78/96. Sense of speed comes from camera/optic flow, not unsafe velocity alone. |
| Steering verbs | Force-based yaw/grip, smoothed counter-steer assist, drift, hold airbrakes, remappable sideshift, bounded air pitch/yaw. No free drift mini-turbo. | Gives anti-gravity identity and combat dodge without snaking. |
| Shared energy | Internal integer 0-1000, UI percentage. Initial boost drain 180/s, energy pit 320/s, respawn 500; tune from race telemetry. Weapon absorption restores catalog values. | One economy is legible; integer scale supports networking. Reject separate health plus boost bars and free boost cooldown. |
| Respawn | Offline logical deadline tick +60; online `respawnAt = deathAt + 1,000,000 μs`. Restore literal death pose, zero velocity, 250 ms racer collision ghost and 1 s damage grace. Falls without a kill use separate safe-frame recovery. | Meets the brief literally. Reject nearest-gate or silent track projection for combat kills. |
| Inventory/roster | Sol's one weapon + one utility slots and six-weapon/four-utility launch catalog; add absorb to weapon slot. Consolidate Quake/EMP naming so every item has one clear role. | Ensures counters can be held while preserving offensive decisions. Reject inventory wheels and unavoidable leader attacks. |
| Pickup placement | Authored family rows, 2-4 lateral sockets, 5 s shared respawn. Roll family legality → server time-gap weighting → rarity. | Combines both drafts' strongest placement and fairness ideas. Reject raw ordinal-only tables and optimal-line freebies. |
| AI | Compiled lateral line + target-speed array; real input intents; time-gap/dead-zone competition director; tier differences primarily line/noise/reaction/strategy. | Fair and inspectable. Reject physics bonuses, teleport recovery except explicit softlock reset, and omniscient item reactions. |
| Online AI | None in v1; 2-8 humans. | Reject host-simulated AI and migration complexity. |
| Multiplayer authority | SpacetimeDB owns lobby/match clock/gates/laps/pickups/inventory/energy/damage/death/respawn/results. Browser owns movement under validation and correction to last accepted state; label casual. | Honest fit for current stack. Reject client hit/damage claims, host authority, and ranked-security claims. |
| Combat networking | Generated shared track artifact; hybrid track-space/rewound-3D server resolution; predicted client presentation only. | Handles 3D/flyovers without server Rapier. Reject pure `(s,lateral)` for every weapon and full server physics on launch critical path. |
| Lobby scope | Match-scoped coded rooms + quick join, transactional rematch, 15 s reconnect grace then DNF. No skill matchmaking/accounts/ranked. | Small but actually deployable; reject one global room as public v1. |
| Visual direction | Dark indigo/slate base; cyan navigation, magenta rivalry/threat, amber hazard, mint energy. Strong road/background separation, near-field rhythm, one landmark per sector. | Both drafts agree; reject glow/fog as substitute for authored geometry. |
| Postprocessing | Selective bloom + tone map + subtle vignette; event-only aberration/noise; no motion blur. ≤2 ms Tier A. | Protects road readability and fill rate. |
| Assets | CC0/Quaternius/Poly Haven/Kenney first; manifest/provenance; generated concepts/ships/audio only after credentials or through Grok route explicitly available to the production team; technical-art cleanup mandatory. | Matches verified missing keys. Reject generator output as an assumed dependency and unlicensed temporary music. |
| Audio | Three-band own engine + boost layer, nearest four remote engines, pooled weapon/UI/impact voices, CC0/CC-BY or commissioned adaptive music, captions for critical cues. | Imports Fable's best specificity with honest sourcing. |
| Performance | Desktop Tier A: ≤180 calls, ≤900k normal visible tris, ≤256 MB texture estimate, ≤512 MB process memory, post ≤2 ms, sim+physics+AI ≤4 ms, 60 fps/≥55 1% low. | Unifies both budgets and separates GPU textures from process memory. |
| QA | Test hooks and simple line bot in Phase 1; unit/golden/compiler tests per system; Playwright functional + seeded visual states; bot fairness/combat/soak; network fault and malicious-client tests; real-GPU perf only. | Automation grows with the game. Reject late QA and brittle universal image-entropy thresholds as sole pass/fail evidence. |
| Target devices | Desktop evergreen browsers, keyboard/gamepad. Responsive/narrow UI and low quality tier tested; touch/mobile gameplay explicitly post-v1. | Honest launch promise and manageable AAA bar. |

---

## 5. Recommended roadmap changes for synthesis

1. **G0 — Consume the separate visibility/steering fix** exactly as both drafts already state; do not duplicate it.
2. **N0 — Contain and correctly label the existing network prototype:** close the respawn teleport bypass, wire checkpoints end to end, split offline/online lifecycle authority, define rematch and disconnect/DNF, and feature-gate multiplayer until the flow test passes. This is not the full multiplayer phase.
3. **Phase 1 — Time-trial vertical slice:** 60 Hz runtime, generated track artifact/RMF compiler, CraftController with airbrakes/sideshift, camera/readability, shared energy/boost, onboarding, minimal audio, deterministic hook and simple line-bot smoke. Stop if five blind testers cannot complete and rate control/readability at least 4/5.
4. **Phase 2 — Offline combat:** exact death-pose respawn, two-slot inventory plus weapon absorb, pickups, consolidated roster, telegraphs/counters, balance instrumentation.
5. **Phase 3 — AI and Black Rain Foundry:** lateral-line AI, bounded competition director, AI combat, second track greybox/art. Both tracks and eight bots must pass before schema/network contracts freeze.
6. **Phase 4 — Multiplayer v1:** reproducible/pinned SpacetimeDB toolchain, match-scoped schema, authoritative lobby/laps/results, authoritative item/combat/logical respawn deadlines, then movement validation/interpolation and fault/security tests. Human-only casual rooms.
7. **Phase 5 — Production art/UI/audio/performance:** conditional generator lane, ship/environment kits, complete UI state matrix, licensed music, adaptive quality, actual device budgets.
8. **Phase 6 — Release proof:** full bot/visual/network soak, photosensitivity/accessibility, license/secret/schema migration, scorecard/fresh-eyes review, release notes that disclose client movement authority and desktop-only target.

The critical path stays feel → energy/combat → AI → second track → match-scoped multiplayer → production/performance → release. N0 is a safety/integration gate alongside G0, not permission to pull the full multiplayer phase forward.

## Final recommendation

Converge on Sol's staged architecture and release gates, but materially enrich Phase 1-3 with Fable's airbrake/sideshift handling, lateral-offset racing lines, gap-based item/AI logic, weapon absorption, engine audio layering, and optic-flow set dressing. Correct both reports' multiplayer assumptions with the five live findings before synthesis is approved. The single most important wording change is to stop describing the current or v1 movement model as server-authoritative prediction/reconciliation: it is casual client movement authority with server-owned rules and validation until a real authoritative movement service exists.
