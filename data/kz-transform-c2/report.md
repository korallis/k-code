# K-ZERO TRANSFORMATION PLAN — co-draft C2 (Fable 5)

**Date:** 2026-07-13 · **Repo:** k-zero @ `34ca048` (main, clean) · **Kind:** planning scout (no implementation code)
**Direction (captain, binding, supersedes earlier engine scope):** k-zero pivots from a web app to a **native iOS/iPadOS app on the Unity engine**. Unity is chosen — this plan does not re-litigate the engine; residual risks are noted briefly where material (§2.3). The bar is unchanged: full 3D battle racer, **everything player-visible is a real generated 3D asset** (Tripo API primary, web fallback), visual class = Forza Motorsport / GTA 5 / Spider-Man scaled to the platform's ceiling, locked 60 fps (120 Hz ProMotion where achievable), buttery-smooth controls, and evidence artifacts on every claim.
**Grounding inputs:** forensic visual audit `kz-visaudit-v7` (`/Users/leebarry/firstmate/data/kz-visaudit-v7/report.md` — still the asset ground truth; its §4 lever table and §8 recommendations carry into the Unity target), direct source reads of this worktree (file:line cited), the `threejs-aaa-graphics-builder` + `threejs-3d-generator` skills, and five research annexes (three web-engine annexes now feeding §16 rejected-alternatives + asset economics; two Unity annexes feeding §3/§9/§10). Citations: Appendix B.

**Plan skeleton (captain's re-aim, plus the required-tools addition):**
§1 ground truth · §2 direction + what the pivot means · §3 Unity architecture (URP/HDRP, Metal, device tiers, ProMotion) · §4 port strategy (TS→C#) · §5 asset pipeline (Tripo→Unity, total coverage) · §6 controls (touch+gamepad+steering fix) · §7 SpacetimeDB multiplayer · §8 stability/perf verification · §9 toolchain/CI/gating · §10 REQUIRED-TOOLS inventory (captain checklist) · §11 fate of the web build · §12 roadmap reconciliation · §13 milestones · §14 Tripo credit budget · §15 risks & open questions · §16 rejected alternatives · Appendices A–C.

---

## 0. Executive summary

- **The pivot changes the renderer, not the game.** k-zero's real IP — the deterministic fixed-tick sim, craft-handling math, compiled track artifacts, energy/items/weapons/AI balance, and the SpacetimeDB server module — is engine-agnostic by construction and ports to C# largely mechanically (§4). The web build's presentation layer (R3F components, meshopt/KTX2 web pipeline) is what dies, and per the audit it was the rejected part anyway.
- **Asset ground truth carries unchanged:** the audit's polygating diagnosis (AI-opponent boxes, LOD box-pop, 8-bit-normal/1k-texture crushed heroes) and its 12-category violation inventory define the generation program. Unity actually *simplifies* the fix: raw 4k Tripo GLBs import directly (no meshopt step — Unity re-encodes to ASTC itself), and Unity's LODGroup dithered cross-fade kills popping natively (§5).
- **Rendering:** URP on **Unity 6.3 LTS** (pinned; HDRP officially does not support iOS — §3), with a device-tier table (A14 baseline → A17 Pro/M-series tiers) mapping every audit lever (shadows, AO, bloom-on-emissive, ACES+LUT, STP upscaling, 120 Hz ProMotion, thermal governor) to concrete cited URP features. 60 fps is enforced by the same evidence discipline as before: frame-time series, not averages (§8). Mandatory cash outlay on the Personal-license path is just Apple's $99/yr; the first real cost triggers are a Unity Pro seat ($2,310/yr, required over $200K revenue/funding) and SpacetimeDB Maincloud Pro ($25/mo) before external beta (§10).
- **Controls:** the twitchy-steering diagnosis (§1.3) is design-level and survives the pivot — digital steer through a linear 0.31 s ramp into a speed-invariant 60°/s yaw authority with near-instant lateral kill and a 1.5× counter-steer slam. §6 re-architects input→response for touch + gamepad + keyboard with shaped curves, speed-scheduled authority, and a piloted feel-acceptance protocol with recorded input+telemetry evidence.
- **Multiplayer:** the SpacetimeDB **server module survives as-is**; the C# client SDK replaces the TS client; the P4 gameplayHash handshake contract carries (§7). The queued kz-n0-fix work remains valid because it fixes the module, not the client.
- **Delivery:** ~30 single-PR milestones in 6 file-ownership lanes (§13); Tripo program ≈ 5.4–8.3k credits of 24,170 (§14); required tools split into captain-only items (Apple Developer Program, Unity license decision, signing) vs agent-installable items (§10).

---

## 1. Ground truth — current state, with evidence

*(This section predates the Unity pivot and remains the factual baseline: it is what the port starts from, what the asset program must replace, and what the audit measured. Target-state sections re-aim to Unity from §2 onward.)*

### 1.1 Renderer state of the web build (the "AAA levers" today)

| Lever | Current state | Evidence |
|---|---|---|
| Renderer | WebGLRenderer via R3F `<Canvas>`; `gl={{ antialias: true }}` (MSAA, 4 samples measured) | `src/game/Scene.tsx:281-286`; audit §1 (SAMPLES=4) |
| DPR | Hard-capped `dpr={[1, 1.75]}` → ~1680×945 internal on a 2× Retina 1080p panel | `Scene.tsx:285`; audit §1 finding #1 |
| Color space / tone mapping | Not set anywhere in `src/` — R3F v9 defaults apply (SRGBColorSpace + ACESFilmicToneMapping, exposure 1.0); only track/skyline textures set explicit sRGB | grep over `src/` (only hits: `Track.tsx:145`, `Scenery.tsx:475,539`); audit §4 |
| Shadows | **Zero shadows in gameplay.** Circuit lights all unshadowed by design ("Shadow maps double draw-call counts; Tier A uses unshadowed key + rim"); ship meshes force `castShadow=false`; only the dev arena has a shadowed light | `Scene.tsx:209-226`; `craftMeshes.tsx:264-267`; `Scene.tsx:57-68` |
| Lighting rig | ambient + hemisphere + 2–3 theme-tinted directionals; night HDRI as IBL **reflections only** (`background={false}`) | `Scene.tsx:207-229`, `93-101` |
| Background / sky | Flat clear color + fog + drei `<Stars>` points (1400) + a skyline **cylinder** with a 2D JPG | `Scene.tsx:204-233`; `Scenery.tsx:482,470` |
| Post chain | One pass: Bloom (mipmapBlur, intensity 0.82, threshold 0.82). No AO, no motion blur, no grade | `Scene.tsx:253-260` |
| Frame pacing | Fixed 60 Hz sim (`Physics timeStep={1/60} interpolate`), render-rate presentation; catch-up clamp 5 steps/100 ms + overrun metric | `Scene.tsx:235`; CLAUDE.md P1 |
| Budget instrumentation | `RenderBudgetOverlay` → `window.__KZERO_RENDER_BUDGET__` (calls/tris/geo/tex/MB/fps @500 ms + peaks); Tier-A caps 180 calls / 900k tris / 256 MB | `src/game/visuals/RenderBudgetOverlay.tsx:20-40` |
| Measured worst views | Neon TT 144 calls / ~97k tris / 156 MB; Foundry TT 110 / ~114k / 230 MB; Race+AI 149 / ~96k / 156 MB; fps ~89–120 headless | `docs/asset-overhaul-budget.md`; audit §4 live probe |

**Reading:** the web renderer is a deliberately thin "Tier A" configuration; the audit's measured headroom ("visuals are quality-starved, not GPU-starved", ~10–13% of the triangle cap in use) proves the look was a content/pipeline choice, not a platform ceiling. That finding motivated the captain's fidelity pivot; it also means the *game content* (track density, ship quality, VFX meshes) has enormous authored-detail headroom to grow into on A-series/M-series GPUs.

### 1.2 Asset state and the polygating diagnosis

**Diagnosis (audit §2, confirmed against source):** the captain's "polygate" percept decomposes into:

- **A — the field is boxes (critical).** All seven Race AI opponents render `farOnly` box silhouettes at every distance: `PlayerCraft.tsx:1256-1257` (`<CraftVisualMesh family={family} useGlbLod={false} farOnly />`, comment "Keep the seven nearby Race opponents inside the Tier-A draw budget"), resolving to one `boxGeometry` + two `circleGeometry` thrusters (`craftMeshes.tsx:222-234`). Evidence: `kz-visaudit-v7/gifs/race-ai-box-silhouettes.gif`.
- **B — the player pops to a box.** `<Detailed distances={[0, 32, 75]}>` with children [Tripo GLB, same GLB duplicated, box silhouette] — hard swap at 75 m, no hysteresis/crossfade (`craftMeshes.tsx:298-310`).
- **C — hero meshes are soft and quantization-banded.** Shipped `ship-*.glb` are `gltf-transform optimize --compress meshopt` output with all defaults (`scripts/optimize-assets.mjs:87-95`): POSITION i16 / **NORMAL i8** quantization, 4096²→1024² texture downscale, small triangle loss (razor 17,430→15,764 tris, 2.48 MB→432 KB). The i8 normals are a hard-coded cap in gltf-transform's `--meshopt-level high` path (confirmed in its source and in `inspect` of the shipped GLBs — Appendix B.3). 8-bit normals band visibly on smooth metallic hulls under IBL. On top, `getCraftFarLodTransform` applies **non-uniform per-axis scale** (`craftLod.ts:36-41`), further distorting shading/silhouette.
- **D — not topology corruption.** Raw-vs-opt inspection found valid meshes, no NaNs, no missing normals (audit §2 D, `evidence/glb-stats.csv`). The lesson is pipeline discipline (and Unity removes this entire web-optimization stage — §5).

**Raw sources:** 4k f32 raws exist on disk for five ships (razor, viper, pulse, nova, bulwark) under `public/assets/raw/tripo/ships/`; agile/balanced/heavy survive only as crushed outputs → re-download via PROVENANCE task IDs or regenerate (§5.2, §14).

**Total-coverage violation inventory (audit §3 + independent Explore sweep, cross-checked — 12 non-generated player-visible categories):** pickup pads (cylinder+torus+octahedron, `envKit.tsx:471-493`); boost pads/chevrons, recharge strips, edge markings, finish line (`trackSurfaceLife.tsx:68-470`); start grid (`envKit.tsx:381-403`); all weapon/utility VFX meshes (`WeaponVfx.tsx:626-830`); boost exhaust cones (`BoostExhaust.tsx:108-130`); AI craft + player far LOD + ghosts (`craftMeshes.tsx`, `GhostCraft.tsx:57`); near pylons/gantries/mid-buildings/billboard frames (`Scenery.tsx:117-599`); Foundry tunnel "floating blue box panels" (audit `foundry-drive-3.png`); skyline cylinder; stars/rain points; respawn shimmer boxes (`PlayerCraft.tsx:232-251`); destroy burst (`DestroyBurst.tsx:74,143`). Checkpoint gates have **no visuals at all** (`Track.tsx:509-532` invisible sensors). Real generated assets today: 8 Tripo ships (player near/mid only) + 7 Tripo props; CC0 PBR track textures; 2 CC0 HDRIs; 2D skyline/billboard JPGs. ~180 CC0 GLBs on disk are never referenced. `public/assets/PROVENANCE.md` explicitly *celebrates* keep-procedural decisions — the manifest policy itself contradicts doctrine and is rewritten as a coverage contract in §5.6.

### 1.3 Control-feel state (why steering feels twitchy) — carries to Unity as the design diagnosis

1. **Digital input only:** keyboard `KeyboardEvent.code` (`bindings.ts`); no gamepad path (`useInput.ts:24`), steer is discrete ±1 (`steerMapping.ts:10-14`).
2. **Linear ramp:** STEER_ATTACK=3.2/s → full lock in ~0.31 s; release 5.5/s (`steerMapping.ts:20-37`; `tuning.ts:185-189`); constant-rate slope, no ease/expo, reversal sweep 0.62 s.
3. **Torque:** steer × 14,000 N·m × authority × dt (`craftController.ts:470-490`).
4. **Weak speed scheduling:** authority 1.0→0.82 across 0→70 m/s (`tuning.ts:219`; `craftController.ts:463-466`) — 18% reduction where real racers halve+.
5. **Speed-invariant yaw cap:** 1.05 rad/s (60°/s) at all speeds via angvel clamp (`craftController.ts:492-502`).
6. **Instant lateral kill:** LATERAL_GRIP=0.92 **per 60 Hz tick** (`tuning.ts:201`; applied `craftController.ts:442-457`) — velocity vector snaps to heading in ~6 ms; heading jitter = path jitter.
7. **Counter-steer slam:** ×1.5 torque on sign reversal + assist tiers (`tuning.ts:238-245`).
8. **Camera coupling:** chase cam follow rate 10, lookahead 0.18 s (`feelTuning.ts:111,157`) — yaw jitter fully visible.

Net: full authority in a third of a second, the same 60°/s yaw at 250 km/h as at parking speed, instant heading→path conversion, and a 1.5× correction slam. That is "too responsive left/right", mechanically. §6 fixes it in the Unity input/controller port.

### 1.4 Stability/QA harness state (what exists to carry/replace)

- Fall-through: bounded real-Rapier gate in `pnpm test` + seeded boost-heavy soak (`scripts/fallthrough-soak.mjs`, `KZERO_SOAK_SEEDS/LAPS/BOOST`).
- Determinism: seeded RNG, tick-anchored replay, golden snapshot hash, 600-tick artifact replay test (CLAUDE.md P1/P1.3).
- Perf evidence: budget overlay (500 ms sampler, fps only — **no frame-time series/percentiles**); telemetry ring buffer (`src/game/telemetry/ringBuffer.ts`).
- QA: BRB playtest harness, `docs/qa/`; PR #25 (open) adds keyboard-only piloted-evidence assertions for the funplay gate.
- Gap vs the captain's bar (kz-smooth-g1): no frame-time series capture, no hitch classifier, no crash-free-session tracking, no per-maneuver input+telemetry evidence bundle. §8 builds these into the Unity project from day one — cheaper than retrofitting.

### 1.5 Invariants the port must preserve

1. **Sim purity:** fixed-tick sim never does render-rate work; presentation never mutates sim.
2. **Artifact authority:** the game runs on compiled, hashed track artifacts — not live rebuilds; `gameplayHash` compatibility gates multiplayer (§7).
3. **Craft root transform contract:** visuals under the body, no collider coupling.
4. **Fatal-boost / energy / combat caps semantics** (P2.x) — balance is data + pure functions; port, don't redesign.
5. **60 fps + budgets with evidence** — the bar tightens on mobile (thermals), §8 owns it.

---

## 2. Direction — Unity on iOS/iPadOS (captain decision), and what it means

### 2.1 The decision

Unity is chosen for AAA fidelity on Apple hardware. This plan treats that as fixed and optimizes execution: pipeline choice inside Unity (§3), port order (§4), and toolchain (§9/§10). The prior web-engine evaluation (three.js-push vs Babylon vs PlayCanvas, researched with shipped-game evidence) is preserved as the §16 rejected-alternatives record with its full citation annex — its one enduring conclusion matters here: **the old look was never a platform ceiling; it was content + pipeline discipline.** The same discipline requirements (generated coverage, safe asset handling, evidence gates) apply on Unity, or the same failure recurs with prettier tools.

### 2.2 What the pivot buys (stated once, plainly)

- **Fidelity headroom:** Metal + URP gives console-class features on A17 Pro/M-series (real-time shadows + baked GI + probes, HDR output, temporal AA/upscaling, GPU-driven instancing) without browser sandbox costs; 120 Hz ProMotion is reachable for the feel bar.
- **Pipeline sanity for generated assets:** Unity ingests the raw 4k Tripo GLB/FBX sources directly and owns platform texture compression (ASTC) + mip streaming natively — the entire class of "web optimizer corrupted my normals" bugs (§1.2 C) is deleted rather than fixed.
- **Native input:** first-class touch + MFi/DualSense/Xbox gamepad via Unity Input System — the missing analog path that §1.3 needs.
- **App Store distribution** with TestFlight staged rollout — matches the evidence-gated release doctrine.

### 2.3 Residual risks of the pivot (noted briefly, per instruction — mitigations in §15)

1. **Full presentation rewrite:** ~9.9k LOC of R3F `.tsx` does not port; the sim/logic (pure TS) ports mechanically but still needs re-goldening in C#. Sequenced in §4 so a drivable slice exists early.
2. **Physics swap:** Rapier (WASM) does not exist on Unity; §4.4 keeps craft dynamics as *our* math (as today — Rapier only integrates forces and raycasts) over PhysX queries, preserving feel; determinism scope stays same-device/same-build replay (it was already "same-build local replay only").
3. **Reach:** instant-play web → App Store install; the web build's fate is decided explicitly in §11 rather than by neglect.
4. **Team/tooling shift:** agents must drive Unity batchmode + Xcode; §9/§10 make this concrete (CI shape, XcodeBuildMCP/bootstrap-ios for Apple-side automation). Apple-side items (Developer Program, signing) are captain-only — flagged in §10.
5. **License/cost surface:** Unity tier + Apple program + CI minutes — quantified in §10.

---

## 3. Unity architecture — rendering for iOS/iPadOS at the fidelity bar

*(All claims here cite the Unity-rendering annex, Appendix B.4. **[F]** = cited fact, **[J]** = judgment on cited facts.)*

### 3.1 Version + pipeline choice

- **Pin Unity 6.3 LTS (6000.3.x).** It is the only current release with a fixed support window (Dec 2027; 6.0 LTS dies Oct 2026; 6.4/6.5 are quarterly updates that lose support when the next ships; Unity 7 was cancelled at Unite 2025 — features land incrementally in 6.x) **[F]**. Plan one evaluated migration to 6.7 LTS post-ship.
- **URP. HDRP does not run on iOS at all** — Unity's official pipeline comparison lists iOS: HDRP ❌ (URP ✅); HDRP system requirements list no mobile platform; Unity's Metal page says HDRP = macOS only **[F]**. Built-in RP is deprecated as of Unity 6.5 **[F]**. So URP is not a tradeoff, it is the only supported modern pipeline on the platform — and Unity 6 URP carries the former HDRP arguments: **Render Graph** (mandatory in 6.x), **Forward+** and **Deferred+** (6.1, cluster-lit, works with GPU Resident Drawer), **GPU Resident Drawer + GPU occlusion culling** (Metal qualifies), **Adaptive Probe Volumes** with streaming (staff-confirmed mobile support), **SSAO**, **screen-space decals**, **TAA/SMAA/FXAA/MSAA**, **STP upscaler** ("mobile devices that support compute shaders", auto-selects a cheaper mobile path, requires TAA), **HDR display output on iOS 16+**, and 6.3's **Kawase/Dual-filter bloom modes "optimized for mobile"** **[F]**. Unity's own mobile proof point: *Fantasy Kingdom in Unity 6* ships URP + GRD + GPU occlusion + STP + APV at min-spec iPhone 13 **[F]**.

### 3.2 Target rendering architecture (answering the audit's §4 lever table on Unity)

| Audit lever | Unity/URP target |
|---|---|
| Resolution | Native-panel output with **URP render scale / Dynamic Resolution (supported on Metal via `ScalableBufferManager`)** reconstructed by **STP** (T1+). **No MetalFX**: Unity has no native support and states FSR/STP as its cross-platform answer — third-party plugin exists but is not the plan **[F]** |
| AA | **TAA + STP** on T1+; FXAA on T0; MSAA 4x is cheap on Apple tile GPUs *only* when no depth-hungry feature forces a resolve — viable T0 alternative **[F]** |
| Tone mapping / color | HDR rendering on; **ACES tonemap + per-theme color-grading LUT** (32 px LUT; LDR grading + 16 px on T0) via Volume profiles; **exposure authored per track** (the §1 lesson: never default) **[F post list / J values]** |
| Shadows | Main-light **CSM: 2 cascades, 40–60 m max** (fog corridor bounds useful distance); soft shadows Low/off on T0; additional-light shadows off. **URP has no contact-shadow feature** — craft grounding = **blob/AO decal under each craft on every tier** (audit's "nothing contacts the asphalt" cue) **[F/J]** |
| GI / lighting | **All static lighting baked**: lightmaps (track ribbon/architecture) + **APV** for dynamic objects (Enlighten realtime GI is on deprecation path); ONE realtime directional; additional lights baked/per-vertex on T0–T1; Forward+ cluster lights for neon rows on T2+ **[F]** |
| Reflections (the "car paint" seller) | **Baked reflection probes along the corridor** (blending/box projection T1+, off T0); **T2+: one realtime cubemap on the player craft at half rate** — exactly GRID Legends' shipped technique (20 Hz cubemaps); no planar reflections/SSR (GRID cuts SSR first on mobile) **[F/J]** |
| Post | Unity's mobile-friendly list: **Bloom (HQ filtering off; Kawase/Dual on 6.3), ACES+LUT, vignette, chromatic aberration (T2+, speed-tied)**; DoF Gaussian menus-only; **motion blur off on T0/T1** (GRID ships it only at 30/40 fps modes), measured low-sample option T2 **[F/J]** |
| Materials | URP Lit (metallic workflow) from Tripo PBR maps at import; named material kit as material variants (§5.4); GRD constraint: **no `MaterialPropertyBlock`** — per-instance variation via instanced shader-graph properties **[F]** |
| Sky/vista | Generated skybox + 3D vista set (§5 cat F) replaces stars-points + skyline cylinder |
| Texture/memory | **ASTC ladder** (normals/masks 4×4–5×5, hero albedo 6×6, env 6×6–8×8, lightmaps ASTC-HDR 6×6 — A13+ floor fine); mip streaming on; **HD texture pack gated on ≥8 GB RAM** (Feral's GRID gate); app stays **<50% device RAM** (Unity jetsam guidance); **memoryless render targets** for depth/MSAA **[F/J]** |

### 3.3 Device tiers (fallback so 60 never breaks) **[J on cited hardware facts]**

| Tier | Devices (GPU family, RAM) | Target | Scale/upscale | Features |
|---|---|---|---|---|
| **T0 base** | A14–A15, 4 GB (iPhone 12/13/mini, iPad 10th/Air 4) | **60** | ~0.6–0.65, bilinear/spatial (skip STP if GPU-bound) | Baked+APV, 1–2 cascades @ ~40 m, baked probes only, bloom+ACES+vignette, FXAA, no SSAO; mem ≈ 1.5–1.8 GB |
| **T1 mid** | A15 Pro/A16, 6 GB (13 Pro, 14/14 Pro, 15) | **60 locked** (120 option on 13/14 Pro at T0 settings) | ~0.67–0.75 + **STP** | + SSAO half-res, decals, probe blending, soft shadows Low, 2 cascades @ 60 m; mem ≈ 2.5–3 GB |
| **T2 high** | A17 Pro/A18, 8 GB (15 Pro, 16 family, 17) | **60; 120 Hz mode** at T1-level settings | 0.77 + STP @60; ~0.65 + spatial @120 | + half-rate player-craft cubemap, HQ bloom, chromatic aberration, HD texture pack (8 GB gate), HDR-output toggle |
| **T3 max** | M-series iPads, iPhone 17 Pro (12 GB) | 60/**120** at panel res | up to native + STP | Everything + longer shadows + denser instancing (iPad budgets its extra pixels first) |
| Floor | < A14 | **unsupported** (App Store min-spec) | — | — |

Tier seeding at first launch (device identifier + micro-bench), user-overridable. **Thermal governor:** Adaptive Performance **Apple provider** (`com.unity.adaptiveperformance.apple` — thermal levels, CPU/GPU frame times, bottleneck detection) drives a hysteresis ladder: render scale → shadow distance/cascades → SSAO/decals → post extras → **120→60 (→40; 40 divides 120 — GRID Legends ships a 40 fps mode)**; degrade instantly on "serious", upgrade only after 30–60 s stable; **never the sim tick** **[F/J]**. Min-spec floor is a captain decision (§15 Q1).

### 3.4 Frame pacing: 60/120 and the fixed tick

Sim stays fixed 60 Hz with render-rate interpolation — the identical contract to today. iOS specifics **[F]**: Unity defaults to **30 fps** on iOS (`targetFrameRate=-1`; `vSyncCount` ignored) — set `Application.targetFrameRate` explicitly (60, or 120 on T2/T3); enable **"Enable ProMotion Support"** in iOS Player Settings or iPhones cap at 60; rates must divide panel refresh (hence the 120/60/40/30 ladder); `OnDemandRendering.renderFrameInterval` drops menu/pause render cost while the sim continues. 120 Hz is an input-to-photon feel win (the render interpolates the 60 Hz sim); the governor falls back to locked 60 under thermal pressure.

---

## 4. Port strategy — what carries from the TS codebase, what is rebuilt, and in what order

The port is tractable because the repo already enforces a hard boundary: **pure fixed-tick logic modules with unit tests** (no DOM, no three.js in the sim) vs **R3F presentation adapters**. That boundary is the port plan.

### 4.1 Carries as-is (data + protocol, zero rewrite)

| Item | Why it survives |
|---|---|
| **Compiled track artifacts** (`src/game/track/compiled/*.artifact.ts` payloads) | Fixed-point integer data with a version+hash contract (`{compilerVersion, trackId, trackVersion, gameplayHash, artVersion}`) — language-neutral by design. An export step serializes to binary/JSON consumed by a Unity importer (§4.3) |
| **TS track compiler as the authoring tool** | Keeps running in Node (`pnpm track:build`); Unity never recompiles tracks — it imports artifacts. Preserves byte-identical hashes, the golden-fixture test, and the SpacetimeDB module data path unchanged |
| **SpacetimeDB server module** (`module/src/`, TS) | Server-side; clients in any language connect. N0 rules (respawn token, movement limits, monotonic+idempotent checkpoints) carry; `spacetime generate --lang csharp` emits C# bindings (§7) |
| **Track definitions, AI lines/speeds, pickup rows, recharge strips, respawn/grid poses** | Authored data inside definitions/artifacts |
| **Audio pack** (`public/assets/audio/` + catalog + PROVENANCE) | Files re-import; catalog ids map to an AudioClip registry |
| **Tripo raw sources + concepts + provenance ledger** | The §5 asset program's inputs |
| **Balance constants + gate thresholds** (`balance/gates.ts`, energy/weapons tuning) | Data; ports as C# constants with the same names + a parity test |

### 4.2 Ports mechanically (pure logic → C#, re-goldened)

| Module (TS) | Unity home (C#) | Notes |
|---|---|---|
| `runtime/GameRuntime.ts` (fixed 60 Hz, SYSTEM_ORDER, racer gate, catch-up clamp + overrun metric) | `Sim/GameRuntime.cs` (manual accumulator; see §4.4 for physics stepping) | Input ring buffer + quantized `InputIntent` port 1:1 |
| `craft/craftController.ts` + `suspension.ts`, `speedEnvelope.ts`, `surfaceAlign.ts`, `handlingVerbs.ts`, `steerMapping.ts` | `Sim/Craft/*.cs` (Unity.Mathematics) | Pure math; unit tests → NUnit. §6 rewrites the steering-shape parts as part of the port, not after |
| `energy/`, `items/` (inventory, absorb, roll tables), `weapons/` (tuning, controlLoss, hitImmunity, combatWorld), `balance/combatPolicy.ts` | `Sim/Energy`, `Sim/Items`, `Sim/Combat` | Integer energy 0–1000, caps, refunds — straight ports; roll-table sum-100 tests carry |
| `ai/` (driver, tiers, overtake, director, standings, raceSim) | `Sim/Ai/*` | Emits `InputIntent` only — identical contract; seeded `raceSim` + `botDuel` become edit-mode NUnit gates |
| `race/` + `respawn/fallRecovery.ts` | `Sim/Race`, `Sim/Respawn` | Kill-plane/nearest-pose logic reads artifact `respawnPoses` |
| `track/compiler` **runtime loader only** (`loadRuntimeTrack`, `trackSurface.ts`, `isOnRechargeStrip`) | `Track/ArtifactLoader.cs`, `Track/TrackSurface.cs` | Dequantize Q_* fixed-point → floats; parity test: sampled frames vs TS loader ≤1e-5 |
| `feel/feelTuning.ts` + chase-camera math + `feelEvents` | `Presentation/Feel/*` | Presentation-boundary doctrine carries verbatim |
| `persistence.ts` / `settingsStore` | `Meta/Persistence.cs` (JSON in `Application.persistentDataPath`) | Keybinds become Input System rebind data (§6) |
| `telemetry/ringBuffer.ts` | `Diag/Telemetry.cs` | Feeds §8 evidence bundles |
| `onboarding/training.ts` | data asset + overlay | Data-driven steps carry |

**Porting discipline (every port PR):** (a) the C# port, (b) its NUnit test port, (c) a **cross-language parity harness**: the TS suites export fixture vectors (inputs → expected outputs) as JSON; the C# implementation must reproduce them. The handling-metrics baselines (`handlingMetrics.test.ts`: ride-height RMS, steer symmetry, wall glance, envelope speeds) are the golden feel contract — the C# craft must match **before** §6 deliberately changes steering, so feel deltas stay attributable.

### 4.3 Rebuilt natively (no port)

| Web thing | Unity replacement |
|---|---|
| R3F components (scene/track/scenery/craft render side, HUD JSX) | Scenes + prefabs; the track mesh comes from an **editor-time artifact importer** (ScriptedImporter): ribbon/wall meshes, the closed collider slab (§8.3 fall-through contract), checkpoint sensor volumes, pad/strip placements; HUD in UI Toolkit/UGUI |
| Rapier physics | PhysX **as a service**: rigidbody per craft, forces applied by our controller math (as today), raycast suspension via `Physics.Raycast`, hull-vs-slab via mesh/convex colliders, manual stepping (§4.4) |
| pmndrs postprocessing / WebGL pipeline | URP Volume stack (§3) |
| meshopt/KTX2/`optimize-assets.mjs` pipeline | **Deleted.** Unity imports raw GLB/FBX; ASTC + mip streaming at import (§5) |
| `__KZERO_TEST__` Vite-mode hooks | `KZERO_TEST` scripting define + asmdef-gated debug assembly, stripped from release by define (same assert-no-test-hooks doctrine, new mechanism, §9.5) |
| chrome-devtools-axi pilot evidence | Simulator/device capture + Input System event recording + telemetry export (§8) |
| Vercel previews | TestFlight builds per milestone (§9) |

### 4.4 Physics decision (explicit, because it is the riskiest port line)

Keep **craft dynamics ours**: the existing controller already treats the physics engine as an integrator + query service (Rapier applies our forces; suspension is our raycast math; grip/steer/envelope are our equations). Recreate exactly that shape on PhysX: `Physics.simulationMode = Script` with `Physics.Simulate(1/60)` called from `GameRuntime` so tick authority stays ours. Do **not** adopt wheel colliders or PhysX vehicle stacks — they would discard the tuned feel and fixed-tick purity. Rapier-specific behaviors to re-verify on PhysX, each with a dedicated test: (1) closed-slab track collider + CCD vs tunneling (port the fall-through gate + soak, §8.3), (2) damping semantics (Rapier ≠ PhysX numerically — re-derive coefficients from documented feel targets, never copy constants blind), (3) friction/restitution combine rules on hull contacts. Concretely (annex B.4): `Physics.simulationMode = Script`, fixed 1/60 step (docs: variable steps are explicitly non-deterministic), **Enhanced Determinism on**, physics world recreated between races — which preserves PhysX's actual guarantee: repeatable results same-build/same-device. That matches today's documented scope ("same-build local replay only"). **Ghosts/replays ship as recorded quantized pose+state streams** (30–60 Hz + interpolation — the shipped-racer norm; Real Racing 3's Time-Shifted Multiplayer is recorded lap data), never cross-device input-replay; input+hash replay stays a same-device QA tool. Hot craft/AI loops are plain C# structs, Burst-compiled where profiling justifies. *(Unity DOTS Physics rejected for now — §16.)*

### 4.5 Porting sequence (drives §13)

1. **U0 Foundation:** Unity 6 project + repo strategy (§9.3), URP template + Input System, asmdef layout mirroring TS module boundaries — `Sim` asmdef has **no UnityEngine.Rendering reference** (the enforceable successor of "no zustand in sim").
2. **U1 Track in:** artifact export from TS (`track:export-unity`) + ScriptedImporter → drivable greybox with slab colliders + sensors; geometry-parity screenshots vs web.
3. **U2 Craft feel:** GameRuntime + craft math ports + parity goldens; debug free-drive scene; telemetry recorder from day one.
4. **U3 Race loop:** checkpoints/laps/countdown/standings + minimal HUD.
5. **U4 Controls:** §6 architecture (touch/gamepad/keyboard + new steering shape) — lands *behind* the parity goldens so feel deltas are attributable.
6. **U5–U7 Systems:** energy/items/weapons/AI lanes in parallel (pure-logic ports + NUnit gates).
7. **V-waves:** asset generation + import + scene assembly (§5), parallel to U5–U7 by file ownership.
8. **N1:** multiplayer C# client vs unchanged module (§7).
9. **R1:** TestFlight beta + stability soaks (§8) → App Store.

---

## 5. Asset transformation program — Tripo → Unity, total generated coverage

Doctrine restated: **every player-visible thing is a real generated 3D asset** — no primitive/procedural stand-ins. The web build's violation inventory (§1.2) is the work list; Unity import replaces the corrupting web optimizer; the provenance manifest becomes an enforced contract (§5.6). Generation stays **Tripo API primary** (`TRIPO_API_KEY` via `op read "op://Dev-Env/h4vrivdhvlrkjmwgnpacbwko6i/credential"`), Tripo web/Studio fallback when the API fails or a result needs manual curation. Credits: §14.

### 5.1 Category program (A–H)

| Cat | Surfaces (from §1.2 inventory) | Generation plan | Runtime plan (Unity) |
|---|---|---|---|
| **A. Hero ships ×8** | player + **AI field + ghosts** — one family of assets for all | Reimport 5 raw 4k sources; re-fetch or regenerate agile/balanced/heavy (§5.2). Optional quality uplift pass: multiview/image-to-model regen for any hull the captain rates <bar at close range | One prefab per family: LODGroup (LOD0 hero ~15–20k tris, LOD1 ~5–8k, LOD2 ~1.5–3k) with **dithered cross-fade**; AI ships use the SAME prefabs (deletes §1.2-A); per-family accent material variant |
| **B. Pickups/drops + pads** | pickup pads, item crystal, floor ring | Tripo text_to_model: pad base unit, family crystal set (offense/defense/utility/wildcard variants), holo-ring emitter | Instanced placements from artifact `pickupSockets`; idle rotate/pulse; collect burst (cat F) |
| **C. Track surface layer** | boost pads, recharge strips, start grid, finish line, edge markings | Tripo: boost-pad chevron module, recharge strip module (emissive mint), start-grid pad, finish-line arch/strip; markings become generated decal/trim meshes | Placed from artifact transforms; emissive drives bloom; **checkpoint gates get real generated arch meshes** (today invisible — new readability win) |
| **D. Weapons/projectiles/impacts** | pulse bolt, arc, mine, seeker, rail beam, EMP ring, shield bubble, decoy, muzzle/impact/collect bursts, boost exhaust | Tripo: mine, seeker missile, decoy drone, shield emitter frame as real models; bolts/beams/rings/bursts as **generated mesh + authored shader/VFX hybrids** (mesh cores generated; motion/glow via URP shader graph + particles) | Pooled prefabs mirroring `WeaponVfx` pools; VFX stays presentation-only |
| **E. Trackside structures** | pylons, gantries, mid buildings, billboard frames, tunnel segments, barriers | Tripo kit-of-parts per theme: Neon (pylon, gantry, tower blocks ×3, billboard frame, barrier) + Foundry (tunnel arch segment!, stack/crane variants exist, pipe rack, barrier) — ~10–14 modules/theme | GPU-instanced placements (GPU Resident Drawer); LODs per module; kills the "Amiga skyline" + the floating-blue-boxes tunnel |
| **F. Vistas/skybox** | skyline cylinder, stars, rain | Generated 4k+ panoramic skybox per theme (image gen → cubemap/HDR) + 3–5 large Tripo vista landmarks per theme for parallax; rain/stars re-authored as URP VFX with generated sprite sheets | Skybox material + far vista ring outside the corridor; fog retuned so it reveals depth, not emptiness |
| **G. Craft support visuals** | respawn shimmer boxes, destroy burst, ghost tint | Shield-shell generated mesh (reuse D shield frame), destruct debris set (Tripo debris chunks) + particles | Pooled |
| **H. UI/garage** | ship-select pedestal scene, menu backdrop | Existing gen 2D carries; add a real 3D garage scene using A-ships on a generated pedestal/hangar model | Lit showcase scene with Neutral tone mapping (§3.2) |

Track ribbon/walls: geometry is **gameplay authority** (compiled artifact) and stays compiler-generated; every visible aspect of it gets generated *surfacing* (PBR texture sets + cat-C trim/edge modules) so no player-visible surface reads as a stand-in. Flagged as a doctrine interpretation for captain sign-off (§15 Q3).

### 5.2 Hero-ship recovery (the polygating fix, permanent)

1. **Source of truth = raw 4k Tripo GLBs** (5 on disk; re-download agile/balanced/heavy via their PROVENANCE task IDs — Tripo output URLs expire, so if expired, regenerate ~3×60 credits or convert from archived task via `conversion`; §14 budgets both).
2. **No intermediate optimizer.** Raw GLB → **editor-time import via `com.unity.cloud.gltfast` 6.19.0** (first-party; maps glTF metallic-roughness directly to URP Lit) → Unity owns mesh + ASTC texture encode; import plain-PNG GLBs and let Unity's importer compress (no KTX2/meshopt runtime loading needed for a native app). Fallback for any asset whose materials misbehave: Tripo `convert_model` → FBX (`fbx_preset`, PNG textures ≤4096) through Unity's native model importer, re-wiring maps to URP Lit (B.5). The `optimize-assets.mjs` stage and its i8-normal cap cease to exist on the app path.
3. **Uniform scale only:** importer normalizes by longest-axis uniform scale + pivot to hull center-bottom; footprint fit never squashes axes (deletes §1.2-C's non-uniform distortion; visual footprint checked against the 3.4 m body contract in a PlayMode test).
4. **LOD chain per ship:** LOD0 = raw mesh (~15–20k tris); LOD1/LOD2 generated via **Unity 6.3's Mesh LOD** (automatic import-time chains sharing one vertex buffer, ≥256 tris, ~½ indices per level) or Tripo `smart_low_poly`/`highpoly_to_lowpoly` server-side — A/B on one ship first, both budgeted (§14); note Mesh LOD does not simplify materials, which is fine for heroes. **LODGroup dithered cross-fade (Bayer)** kills the pop; with GPU Resident Drawer, animated cross-fade falls back to static distance-based dither — still pop-free (B.4). The long tail of props uses Mesh LOD wholesale.
5. **Per-asset verification gate (§5.5) before any ship PR merges.**

### 5.3 Texture strategy (iOS)

ASTC everywhere (Unity's recommended iOS format, A8+) with the B.4 ladder: normals/masks 4×4–5×5, hero albedo 6×6, environment 6×6–8×8, lightmaps ASTC-HDR 6×6; mipmaps + **Mipmap Streaming on** (per-texture "Stream Mipmap Levels" + Quality memory budget); heroes keep 2k albedo/normal/ORM from the 4k sources (import-time max-size per platform — never a lossy pre-pass); world modules 1–2k; an **HD texture pack gated on ≥8 GB devices** (GRID Legends precedent) lets T2/T3 use more without sinking T0. Hard budget: total app under ~50% of device RAM (Unity jetsam guidance) — per-tier texture budgets set at V-wave start (§8.5).

### 5.4 Materials

URP Lit metallic workflow from Tripo PBR maps; a named **material kit** (hull/panel/trim/glass/emissiveSignal/hazard/reward/groundContact — same roles as the skill's kit, §1.1 materials.ts successor) implemented as material variants so accent recolors don't multiply shaders; emissive intensity authored per role so bloom reads as designed signal (§3.2).

### 5.5 Per-asset verification gates (the "never polygate again" mechanism)

- **Gate A — import report (automated, every asset):** editor script emits per-asset JSON: tri counts per LOD, texture sizes/formats, material/mesh counts, bounds, uniform-scale check. Asserts vs manifest expectations (e.g. hero LOD0 ≥ 12k tris, normals present, no >2× bounds drift). The class of silent i8-normal corruption fails here loudly.
- **Gate B — visual diff (automated + eyeballed):** fixed showcase scene (camera ring 6 angles, fixed HDRI + key light, albedo/normals-as-color/glossy passes) renders each asset → PNGs committed as evidence; diffed against the previous accepted set on change (pixel threshold), and against Tripo's own `rendered_image` preview on first import (human check: "does the import look like what Tripo made?").
- **Gate C — in-scene budget:** worst-view capture with the ported budget overlay (§8.5) after each wave lands; frame-time series on Base-tier device.
- Evidence paths recorded in the manifest row (§5.6); a PR without its gate artifacts fails review (BRB/no-mistakes hook, §9.5).

### 5.6 Provenance manifest v2 — from ledger to enforced contract

`Assets/Provenance/manifest.json` (+ human `PROVENANCE.md` view): per asset — id, category, Tripo task IDs + model version + prompts/concept refs, credits, source-file hash, import settings hash, LOD chain, verification evidence paths, license. Two enforcement points: (1) **coverage test** — an editor test walks every scene/prefab renderer; any mesh not traceable to a manifest row (or not on the explicit internal-only allowlist: collision proxies, sensor volumes, debug gizmos) **fails CI** — the audit's "ban bare primitives in player-visible paths" as a machine gate; (2) **claim gate** — no "AAA/showcase" claim in any PR without manifest coverage = 100% and Gate A–C artifacts attached (audit §8.6 carried forward).

---

## 6. Control-feel workstream — touch + gamepad + the steering fix

### 6.1 Input architecture (Unity Input System)

One action map (`Drive`): Steer (axis), Thrust, Brake, Boost, AirbrakeL/R, SideshiftL/R (tap), Fire, Utility, Pause — bound per device class:

- **Gamepad (MFi/DualSense/Xbox):** left stick X = analog steer (response curve §6.3), RT/LT analog thrust/brake, bumpers = airbrakes, B/X = fire/utility, stick-flick or d-pad double-tap = sideshift; rumble on impacts/boost (light, capped).
- **Touch (the default mobile scheme):** **auto-throttle ON by default** (mobile-racer norm); left half = horizontal **steer slider** (thumb drag from touch-down origin, ±40–60 pt = full lock, resets on lift) with optional **tilt steering** (accelerometer, sensitivity + deadzone settings); right side = buttons: Boost (hold), Fire, Utility, Brake/Airbrake rocker; double-tap side zones = sideshift. Core Haptics feedback on hits/boost/absorb. All zones/sizes respect safe areas; left/right-handed mirror option.
- **Keyboard (editor/dev + iPad hardware keyboards):** current binds carry via the rebind system; keyboard synthesizes analog steer through the §6.3 shaping layer (never raw ±1 to the sim).

All devices produce the same `InputIntent` quantized struct into the ring buffer — the sim contract (§4.2) is device-blind, which keeps replays/ghosts and bot QA valid.

### 6.2 Why it feels twitchy (diagnosis recap → design targets)

From §1.3: instant-onset linear ramp to full lock in 0.31 s; 60°/s yaw authority identical at all speeds; heading→path conversion in ~6 ms (0.92/tick lateral kill); 1.5× counter-steer slam; stiff camera. Design targets, phrased as player-facing outcomes: (1) small corrections at speed move the craft a small, proportional amount; (2) full lock is reachable but *progressive*; (3) direction changes never snap the tail; (4) the same physical flick feels the same at 30 and at 88 m/s in *screen-space result*, which means authority must fall with speed; (5) touch and stick feel equivalent in outcome.

### 6.3 Steering response architecture (the fix, in the C# port)

Layered, each independently testable and tunable in a `CraftTuning` ScriptableObject (live-editable in editor + dev builds — the Leva successor):

1. **Device shaping:** analog sources get deadzone (radial, ~0.08) + **expo response curve** `f(x)=x·|x|^k`, k≈1.6–2.0 (small-input precision); digital sources synthesize analog through a **critically-damped smoother** (target-seeking with ease-in), replacing the constant-rate linear ramp — onset slope starts near zero instead of stepping to max.
2. **Command scheduling vs speed:** steer command → target yaw rate via an **authored authority curve** (AnimationCurve): max yaw rate ≈ 1.05 rad/s at low speed easing to ≈ 0.45–0.55× that at terminal (vs today's 0.82 torque-only scaling with an unscaled cap). One curve, visible, tunable, testable.
3. **Yaw-rate controller with slew limit:** torque chases target yaw rate through a PD loop with a hard **yaw-acceleration limit** (kills the 14 kN·m step-slam and the 1.5× reversal spike — counter-steer assist becomes *damping of overshoot*, not extra torque).
4. **Grip/carve model:** per-tick 0.92 lateral kill → **exponential lateral-velocity decay with an authored time constant** (~80–140 ms at race speed, speed-scheduled): the craft *carves* into the new heading instead of snapping; drift keeps low grip + higher yaw cap semantics; `gripRedirect` energy-preserving redirect carries.
5. **Assist tiers:** Rookie/Pro/Elite from `ai/tiers` philosophy applied to the player: Rookie = stronger yaw damping + mild auto counter-steer + steering-sensitivity floor; Elite = raw curves. Replaces `COUNTER_STEER_TIER`'s torque multiplier design.
6. **Camera decoupling:** chase camera gets a small yaw smoothing/lag budget (feelTuning port) so residual craft jitter is not amplified on screen; FOV/shake untouched.

### 6.4 Feel-acceptance protocol (piloted, evidence-backed — kz-smooth-g1 directive shape)

- **Instrumented maneuver set** (recorded on device, real input): slalom ×6 gates; 90° corner L and R at fixed entry speeds; high-speed lane change; full-lock reversal at terminal; correction-after-wall-glance; boost-engaged corner.
- **Evidence bundle per session (committed):** Input System event trace + 60 Hz telemetry series (steer command, target/actual yaw rate, lateral velocity/accel, path vs racing line) + screen capture; exporter is `Diag/Telemetry` (§4.2).
- **Objective gates:** yaw-rate step response overshoot < 10%, settle < 250 ms; measured yaw-rate-vs-speed envelope within ±8% of the authored curve; lateral-jerk RMS in the slalom below the recorded pre-fix baseline by ≥40%; zero oscillation growth in the reversal test.
- **Subjective gate:** ≥4/5 "buttery" rating from ≥3 piloted sessions (incl. the captain) on both touch and gamepad; any "finicky" report reopens the milestone.
- Baselines: record the same maneuvers on the C# parity build (pre-fix, §4.2) so before/after deltas are attributable and quantified.

---

## 7. Multiplayer — SpacetimeDB via the C# SDK

- **Server module unchanged.** `module/src/` (TS) keeps running on SpacetimeDB; clients are language-independent. N0 rules carry: server-token respawn, movement limits on server elapsed time, monotonic+idempotent `cross_checkpoint`.
- **Client:** SpacetimeDB Unity SDK via UPM git URL (`com.clockworklabs.spacetimedbsdk`; C# SDK 2.1.0 line, keep within the server's 2.x — server v2.3.0 current) + `spacetime generate --lang csharp --out-dir module_bindings` **from the same TypeScript module** (officially supported: C# clients against Rust/TS modules — B.5). `SpacetimeMatchAdapter` ports as `Net/SpacetimeMatchAdapter.cs` mirroring the TS adapter's phase/clock authority; `LocalMatchAdapter` equivalent keeps **Solo = zero connection** (N0 containment doctrine carries verbatim). **Week-1 spike (in N1 acceptance): on-device iOS IL2CPP connectivity** — the SDK needed WebGL-specific fixes as recently as v2.3.0, and no explicit iOS support statement exists in its docs; verify before building on it (B.5). Hosting: Maincloud free tier (2,500 TeV/mo, idle DBs auto-pause) for dev; **Pro ($25/mo) before external TestFlight**.
- **iOS specifics:** reconnect/resubscribe on background→foreground (`applicationWillEnterForeground`), cellular-vs-wifi tolerance in the movement-limit windows (server-side already time-based), ATS/TLS for the SpacetimeDB Cloud endpoint.
- **gameplayHash handshake (P4 contract carried):** match row stores `{compilerVersion, gameplayHash}`; client sends its artifact hash; mismatch → clean "incompatible version" state. Because the Unity client consumes the *same compiled artifacts* (§4.1), hashes remain comparable across web and app — cross-play with a frozen web demo stays technically possible but is **out of scope** (§11).
- **kz-n0-fix stays valid and stays first:** the 3 latent bugs live in the module/N0 protocol (see `data/kz-p4-plan-c5/converged-plan.md`), not the TS client — fix before any client (TS or C#) builds on it (§12).

---

## 8. Stability & performance verification on iOS (series, not averages)

### 8.1 Frame-time series (the core instrument)

`Diag/FrameTimeRecorder`: per-frame CPU/GPU timings via Unity's frame-timing APIs (+ `Time.unscaledDeltaTime` fallback), ring-buffered and exported as CSV/JSON series per session. Report format per gate: p50/p95/p99 frame time, hitch counts (>16.7 ms at 120, >33 ms, >50 ms), longest hitch, thermal state timeline, memory series. **Averages are explicitly non-acceptable evidence** (captain directive in kz-smooth-g1). Sources (B.4/B.5): Unity FrameTimingManager (also feeds Dynamic Resolution) + **Adaptive Performance Apple provider** (thermal level, CPU/GPU frame times, bottleneck flag) + `Application.thermalState`; deep dives via Xcode Instruments (`xctrace`, Metal System Trace / Game Performance) and MetricKit/Organizer field data. Simulator is never perf evidence (Metal-on-Simulator ≈ apple2 feature family — functional smoke only).

### 8.2 Crash-free soaks

Automated soak mode (scripting define): AI-only races looping N hours on device, telemetry + crash reporting armed; acceptance = **zero crashes, zero unbounded memory growth trend, zero thermal-runaway lockups** across ≥3 devices × ≥2 h before TestFlight externals; crash/ANR tracking in production via the §10 crash tooling with crash-free-session % surfaced per build.

### 8.3 Fall-through stress regression (contract carried from the web build)

The closed-slab collider + CCD contract (§1.4, CLAUDE.md sharp edge) re-implements in the artifact importer (§4.3) and gets the same two-tier guard: (1) bounded PlayMode gate in CI — seeded boost-heavy laps on both tracks, zero fall-throughs/zero safe-frame recoveries; (2) long soak (`KZERO_SOAK_*` env equivalents) run per release. PhysX-specific additions: CCD flags on craft bodies, mesh-collider cooking options pinned, a wall-clip stress lane (the soak already does boost-heavy).

### 8.4 Piloting/telemetry evidence bundles

The §6.4 recorder is general: every milestone that claims a feel/perf outcome attaches input traces + telemetry series + capture. One shared format, one exporter, reused by BRB gates.

### 8.5 Budget instrumentation (RenderBudgetOverlay successor)

`Diag/RenderBudgetHud` (dev builds): draw calls/set-pass, tris, texture memory, resolution scale, tier, fps + p95 — sampled 500 ms, peaks retained, exportable; budget table per device tier defined at V-wave start and enforced at every wave gate (successor of TIER_A; starting envelopes from B.4: memory ≈1.5–1.8 GB on T0 4 GB devices, ≈2.5–3 GB on T1 — the "<50% device RAM" jetsam rule — with set-pass/tri caps measured on the U1 greybox and ratcheted per wave rather than guessed).

---

## 9. Toolchain, CI, and quality gating for a Unity iOS project

*(Specifics from the Unity-toolchain annex, Appendix B.5 — versions/prices cited there.)*

### 9.1 Build path

TS-era `pnpm build`/Vercel is replaced by: **Unity batchmode export** (`-batchmode -quit -executeMethod BuildScript.BuildIos` → Xcode project) → `fastlane gym` (xcodebuild archive/export, signing via `match` with certs in a private repo or automatic signing) → `fastlane pilot` upload authenticated by an **App Store Connect API key** (no 2FA in CI). Two loops: (a) fast inner loop — EditMode/PlayMode in editor + **Simulator smoke** (separate Simulator-SDK build; functional only); (b) evidence loop — device build with `Diag` enabled for frame-series/soak/feel gates.

### 9.2 CI shape (B.5 recommendation adopted)

- **Primary lane: one self-hosted Apple-silicon Mac runner** (macOS Tahoe 26.2+, Xcode 26.6, Unity 6.3 LTS + iOS module, owner signed into Unity Hub once — the clean Personal-license path; self-hosted GH runners are free and the announced platform fee was postponed). Runs: per-merge iOS build → TestFlight internal.
- **Fallback/scale lane (hosted GameCI two-stage):** Unity iOS *export* on a cheap ubuntu runner ($0.006/min, `unityci/editor` iOS image, Library cached, `UNITY_LICENSE` .ulf secret flow) → artifact → short macOS job ($0.062/min) doing only xcodebuild+fastlane. Keeps 10×-billed macOS minutes to the ~10-minute Xcode stage.
- **Per-PR (cheap, ubuntu):** EditMode+PlayMode suites (`Sim` asmdefs are engine-light by design), asset Gate A + §5.6 coverage test, dotnet format/analyzers.
- **Cadence extras:** simulator smoke per merge (self-hosted, via XcodeBuildMCP); weekly on-device run (devicectl + Instruments capture) attached to the Q-lane evidence.
- **Not primary:** Unity Build Automation (workable; 100 free Mac-min/mo then $0.07/min, less Xcode-stage control) and **Codemagic (blocked on Personal — its Unity flow requires a Plus/Pro serial)**. Both only become attractive with a Pro seat.
- **License edges to respect:** batchmode is permitted under standard ToS; CLI `-serial` activation is Pro-only — Personal activates via Hub sign-in per machine; the separate "Unity Build Server" floating-license product excludes Personal (irrelevant to our shape).

### 9.3 Repo strategy

**New repo (`k-zero-app`)** rather than a monorepo subfolder: Unity's LFS-heavy churn (meshes/textures/scenes), different CI runners, and different review artifacts would poison the existing repo's history and hooks — and LFS quotas are per-owner anyway (no monorepo quota benefit, B.5). Git LFS for binary patterns; **GitHub LFS is metered: 10 GiB storage + 10 GiB bandwidth/mo free, $0.07/GiB-mo over** — and **Actions LFS pulls count against bandwidth**, so CI caches LFS objects aggressively (Team plan's 250 GiB if art volume grows). `UnityYAMLMerge` as the merge driver for scenes/prefabs; standard Unity `.gitignore`; **file-ownership lanes = asmdef/folder boundaries** with additive scenes per feature area to avoid scene-file contention. The existing `k-zero` repo remains the home of: the TS track compiler (authoring), the SpacetimeDB module (single server source of truth; C# bindings regenerate against a pinned module commit), and the frozen web build (§11).

### 9.4 Agent operability

Agents drive: Unity batchmode CLI, `xcodebuild`/simulators via **XcodeBuildMCP** (now maintained under getsentry; ~77 tools incl. build/run/test on sim, screenshots, UI snapshots, device ops) and the **bootstrap-ios** skill, fastlane, and device log capture. **Owner-only one-time steps agents cannot do (B.5):** Apple Developer enrollment + agreement acceptance, ASC API key creation, Unity Hub sign-in per build machine, first external-TestFlight Beta App Review submission, physical device trust prompts. Everything else is agent-drivable end-to-end.

### 9.5 no-mistakes / BRB gating (doctrine carried, mechanics replaced)

- **no-mistakes pipeline** continues to gate every landing PR (review, tests, lint, docs, push, PR, CI) — pointed at `k-zero-app`; its test stage runs UTF suites + §5.5/§5.6 gates.
- **BRB playtests** move from browser piloting to **TestFlight/simulator piloting**: the §6.4/§8.4 evidence bundle (input trace + telemetry series + capture) is the required attachment for feel/visual/perf claims; visual claims use §5.5 showcase renders + on-device native-res captures.
- **Claim gates:** "AAA/stunning" requires §5.6 coverage test green + scorecard with device captures (audit §8.6 carried); "smooth" requires §8.1 series on min-spec + Ultra devices.
- **Test-hook stripping** carries as scripting-define + asmdef exclusion, asserted by a release-build scan (successor of `assert:no-test-hooks`).
- **App Review readiness** is a standing gate item: no placeholder content, accurate age rating, loot-box odds disclosure only if paid random items ever appear (none planned), account-deletion rule only if accounts appear (B.5).

---

## 10. REQUIRED-TOOLS inventory

*(Every item: what it is · pinned version · license/cost · provided-by · setup. All versions/prices cited in Appendix B.5. ✅ = already available in this environment. The **Captain-only checklist** at the end is the actionable summary.)*

| # | Item | What it is | Pin | License / cost (USD) | Provided by | Setup |
|---|---|---|---|---|---|---|
| 1 | Unity Editor | Engine + iOS exporter | **Unity 6.3 LTS (6000.3.x**, latest patch — 6000.3.18f1 as of Jun 2026; LTS→Dec 2027) | **Personal free** iff revenue+funding ≤ $200K trailing-12-mo (contractor rule counts the client's finances); **Pro $2,310/yr/seat** ($210/mo) REQUIRED $200K–$25M | **Captain** (account + tier decision); agents install | Unity Hub → install 6000.3.x + check **iOS Build Support**; owner signs into Hub once per build machine (activates Personal) |
| 2 | Unity Hub | Editor/license manager | latest | Free | Agents (`brew install --cask unity-hub`); **owner sign-in once/machine** | — |
| 3 | Xcode | Apple toolchain (build/sign/Simulator/Instruments) | **Xcode 26.6** — App Store uploads REQUIRE Xcode 26/iOS 26 SDK since Apr 28 2026 | Free | Captain's Mac hosts; agents drive | **Requires macOS Tahoe 26.2+** (hard dependency on the build Mac's OS); `xcode-select`, accept license, install iOS platform + simulators |
| 4 | Apple Developer Program | Signing, TestFlight, App Store | n/a | **$99/membership yr** | **Captain only** (identity + agreements) | Enroll; create App ID + app record in ASC |
| 5 | App Store Connect API key | 2FA-free CI auth for upload/signing | team key, App Manager/Developer role | Free | **Captain generates**; stored in op for agents | ASC → Users & Access → Integrations → Keys; save KEY_ID/ISSUER_ID/.p8 as secrets |
| 6 | Signing (match or automatic) | Certs + provisioning | fastlane match (certs in private repo) | Free (in #4) | Captain approves; agents operate | `fastlane match` init; or Xcode automatic signing with ASC key |
| 7 | Device matrix | Real-device perf/feel truth | min: 1× A14/A15 (4 GB), 1× A16/A17, 1× ProMotion (A17 Pro+ or M-series iPad) | Hardware cost | **Captain** | Developer Mode on; register UDIDs; trust prompts (owner) |
| 8 | iOS Simulator | Functional smoke ONLY (Metal ≈ apple2 family — never perf evidence) | with Xcode | Free | Agents ✅ (XcodeBuildMCP) | Simulator-SDK Unity build target |
| 9 | glTF import | Tripo GLB → Unity prefabs/materials | **com.unity.cloud.gltfast 6.19.0** (first-party; PBR→URP Lit; editor+runtime) | Free (Apache-2.0) | Agents | UPM add; per-category import presets; FBX fallback via Tripo `convert_model` |
| 10 | Texture tooling | Platform compression + streaming | Unity ASTC importer (primary); Blender only for HDRI/cubemap prep | Free | Agents | §5.3 ASTC ladder presets; Mipmap Streaming in Quality settings |
| 11 | Git + **Git LFS** + UnityYAMLMerge | VCS for binary-heavy repo | LFS 3.x; YAMLMerge ships in Editor | **LFS metered: 10 GiB store + 10 GiB bw/mo free; $0.07/GiB-mo over** (Team plan: 250/250) | Captain (GitHub plan/billing); agents configure | New `k-zero-app` repo; `.gitattributes` LFS patterns + `merge=unityyamlmerge` driver; CI caches LFS |
| 12 | SpacetimeDB CLI + server | Module tooling + local dev server | **v2.3.0** | Self-host free; **Maincloud: free tier 2,500 TeV/mo (idle auto-pause) → Pro $25/mo** before external beta | Captain (Maincloud org/billing); agents install CLI ✅ pattern known | `curl install.spacetimedb.com`; module stays in old repo |
| 13 | SpacetimeDB C#/Unity SDK | Unity client | UPM git URL `com.clockworklabs.spacetimedbsdk` (C# SDK **2.1.0**; keep in server's 2.x line) | Free | Agents | UPM add; `spacetime generate --lang csharp --out-dir module_bindings` |
| 14 | CI runners | Build/test compute | GH Actions: self-hosted Mac (primary) + ubuntu ($0.006/min) + hosted macOS ($0.062/min) fallback | Self-hosted free (platform fee postponed); macOS burns included minutes at 10× | Captain (billing + the Mac); agents author workflows | §9.2 two-lane shape; GameCI unity-builder@v4 + .ulf license secret for hosted |
| 15 | fastlane | gym/match/pilot automation | **2.237.0** | Free (MIT) | Agents | Gemfile + Fastfile in app repo; ASC-key auth |
| 16 | TestFlight | Beta distribution | — | Included in #4 (internal ≤100 instant; external ≤10,000 w/ Beta App Review, 6 submissions/24 h, 90-day builds) | Captain approves testers/first external review | Internal group per merge; external at Q2 |
| 17 | Crash/analytics | Crash-free-session % + symbolication | **Start: Unity Cloud Diagnostics** (included, 10k reports/day) → **Sentry Unity 4.6.0** (free Developer tier; auto iOS dSYM upload) if/when richer triage needed; Crashlytics 13.13.0 = alternative | Free at our scale | Captain (account) for Sentry/Firebase; agents integrate | SDK + dSYM upload step in CI |
| 18 | Perf tooling | Frame-series ground truth | Unity Profiler + **Memory Profiler 1.1.12**, FrameTimingManager, **Adaptive Performance Apple provider**, Instruments/`xctrace` (Metal System Trace, Game Performance), MetricKit/Organizer | Free | Agents ✅ | §8 recorders; weekly device trace |
| 19 | Device farm (optional) | Broader hardware coverage | AWS Device Farm $0.17/device-min (1,000 free min once) or BrowserStack App Live $39/mo | Optional | Captain (account) | Only if the §10.7 matrix proves insufficient |
| 20 | Tripo API | Asset generation | current API + `convert_model` for FBX | **24,170 credits funded** ✅; key via `op read "op://Dev-Env/h4vrivdhvlrkjmwgnpacbwko6i/credential"` | Captain ✅ | §5 program; §14 budget |
| 21 | Image generation | Skyboxes/concepts/decals (threejs-image-generator skill → Gemini API) | existing | Existing key ✅ | Captain ✅ | §5 cats C/F/H |
| 22 | 1Password CLI (`op`) | Secret delivery to agents | existing | Existing ✅ | Captain ✅ | Note: `op-service-account` backlog item removes per-read auth prompts (worth doing before the generation waves) |
| 23 | Agent Apple tooling | Agent-driven Xcode/Simulator | **XcodeBuildMCP** (getsentry, ~77 tools) ✅ + **bootstrap-ios** skill ✅ | Free | — ✅ | Load bootstrap-ios at U0 |
| 24 | Unity Test Framework | EditMode/PlayMode suites in CI | embedded in Editor (UTF 1.5.1+) | Free | Agents | game-ci/unity-test-runner or `-batchmode -runTests` |
| 25 | Audio | Existing pack + ElevenLabs skill for new SFX | existing | Existing ✅ | Captain (key exists) | Re-import per §4.1 |

### Captain-only checklist (each blocks the milestone noted)

1. **Unity license tier decision** — verify the owning entity's trailing-12-month revenue+funding vs the $200K Personal cap (contractor rule counts client finances); buy Pro seat(s) if over. *Blocks P0.*
2. **Build Mac provisioning:** an Apple-silicon Mac on **macOS Tahoe 26.2+** (Xcode 26.6 requirement) dedicated/available as self-hosted runner + one-time **Unity Hub sign-in** on it. *Blocks P0/P2.*
3. **Apple Developer Program** enrollment ($99/yr). *Blocks P3 (TestFlight); simulator work proceeds without it.*
4. **App identity decisions:** bundle id + display name (+ landscape-only confirm, §15 Q5) and the ASC app record. *Blocks P3.*
5. **ASC API key** created and stored in op alongside signing setup (match repo or automatic signing). *Blocks P3.*
6. **Device matrix** (min three devices per row 7). *Blocks C2/Q2 evidence gates.*
7. **GitHub plan/billing** check for LFS (upgrade if art exceeds 10 GiB) + Actions overage policy. *Blocks V-wave scale-up.*
8. **SpacetimeDB Maincloud Pro** ($25/mo) before external TestFlight. *Blocks Q2-external.*
9. *(Carried item)* approve the **op-service-account** fix so generation waves run without auth-prompt stalls.

---

## 11. Fate of the web build

**Recommendation: freeze as a public demo, don't retire silently.**

1. Land the in-flight funplay evidence PR (#25) if it passes on its own merits, then **tag `web-final`** and add a README banner: web = legacy demo of the sim/design; active development moved to the iOS app.
2. The repo stays alive for three living components: the **TS track compiler** (authoring authority, exports Unity artifacts §4.1), the **SpacetimeDB module** (server for the app §7), and the frozen demo.
3. Vercel deploy stays up as the shareable demo (zero marginal cost) but out of the quality gates; no new web features; web-only backlog items close as superseded (§12).
4. Cross-play app↔web: technically plausible (same artifacts/hashes) but **out of scope** — the frozen client would drift from module versions; the module gains the P4 hash handshake precisely so stale clients fail clean.
5. The captain may instead choose full retirement (take Vercel down) — one-line decision, §15 Q7.

---

## 12. Roadmap reconciliation (what folds in, what reorders, what dies)

| Item (state) | Verdict | Rationale / where it lands |
|---|---|---|
| **kz-visaudit-v7** (done) | **Folded in** | Its findings are §1/§5's ground truth; its §8 recommendations map: violation purge → §5 waves; AI+LODs → §5.1-A; ship quality → §5.2; renderer preset → §3; weapons meshes → §5.1-D; evidence gate → §5.6/§9.5 |
| **kz-transform-c2 / x6** (this + co-draft) | Cross-review next per brief | Firstmate relays the other draft; claims here are file:line-grounded for that fight |
| **kz-funplay** (in flight, PR #25 open) | **Complete as the web-baseline record, then retire the lane** | Its piloted-evidence patterns and FUN verdict become the baseline the Unity build must beat; the gate itself is reborn as recurring TestFlight BRB gates (§9.5). Don't start new web fixes from its findings |
| **p3-ai-track2** (queued) | **Dies as an umbrella; residue → U7** | PR #23 already landed AI item-use + balance gates; remaining counterplay/decision-quality polish folds into the U7 AI port + Unity-side funplay findings |
| **kz-n0-fix** (queued) | **Unchanged, do now, existing repo** | The 3 latent bugs are module/N0-protocol-side (see `data/kz-p4-plan-c5/converged-plan.md`); every future client (C# included) inherits them. Zero file overlap with Unity lanes — ideal parallel PR |
| **p4-multiplayer** (queued) | **Reorders: after U3 + N0-fix; client work becomes C#** | §7; gameplayHash handshake contract carries verbatim; SpacetimeDB Cloud plan unchanged |
| **p5-production** (queued) | **Dies as a phase; scope absorbed** | Art → §5 V-waves; audio already produced (re-import §4.1); UI art → §5-H; perf → §8/Q lane |
| **p6-release** (queued) | **Survives, retargeted** | Becomes R1/Q2: App Store release proof — soaks (§8.2), accessibility (reduced-motion/flashes settings carry + iOS accessibility pass), license/credit sweep (CC0 + Tripo terms + audio PROVENANCE), final scorecard vs the visual bar |
| **kz-smooth-g1** (queued) | **Absorbed as the standing gate, closes as a task** | Its captain directive (frame-time series, per-maneuver input+telemetry evidence, zero-bug bar) is implemented *as infrastructure* in §6.4/§8 and enforced per milestone; the final device-matrix smoothness sign-off is Q2 |
| Web-only backlog residue (Vercel preview auth note, `?trackBuilder=legacy` A/B, test-hook Vite mechanics) | **Dies with the freeze** | Superseded; documented in the freeze PR |

Sequencing note: nothing in the old queue blocks U0–U2; kz-n0-fix and V-wave Tripo generation can run **concurrently with** the foundation milestones from day one.

---

## 13. Milestone program (single-PR increments, 6 parallel lanes)

Lanes are disjoint by folder/asmdef ownership (§9.3). Every milestone = one PR through no-mistakes with the listed evidence. Order within a lane is strict; across lanes, parallel. (Sizing: S/M/L ≈ agent-days 1/2-3/4+.)

**Lane P — Platform/foundation**
- **P0** (M): `k-zero-app` repo + LFS + Unity 6 LTS project + URP mobile template + asmdef skeleton (`Sim`/`Track`/`Presentation`/`Net`/`Meta`/`Diag`) + EditMode CI. Evidence: CI green, empty-scene device build boots on simulator.
- **P1** (L): TS `track:export-unity` (artifact binary export + schema doc, PR in old repo) + Unity `ArtifactImporter` (ScriptedImporter → ribbon/wall meshes, slab colliders, sensors, sockets, respawn/grid poses). Evidence: hash parity log TS↔C#, greybox drive-through capture, importer unit tests.
- **P2** (M): iOS build pipeline (batchmode → Xcode → simulator) + XcodeBuildMCP wiring. Evidence: scripted build artifact + boot capture.
- **P3** (M): TestFlight internal pipeline (signing via ASC API key, fastlane upload). Blocked on captain checklist #2–4. Evidence: internal build installable.

**Lane S — Sim port (pure C#)**
- **S0** (M): `GameRuntime` + tick/ring-buffer/`InputIntent` + seeded RNG + parity fixtures. Evidence: NUnit + fixture parity green.
- **S1** (L): craft math port (suspension/envelope/align/verbs/steer as-is) + PhysX adapter (manual `Physics.Simulate`) + debug free-drive scene. Evidence: handling-metrics goldens within tolerance vs TS baselines; §8.3 bounded fall-through gate green.
- **S2** (M): race loop (checkpoints/laps/phases/standings) + minimal HUD. Evidence: 3-lap TT completes; line-bot smoke port (headless laps) green.
- **S3** (M): energy + respawn/fall-recovery + recharge strips. Evidence: ported energy tests (+59/+60/+61 pose exactness) green.
- **S4** (M): items/inventory/pads + roll tables. Evidence: sum-100 + absorb tests green.
- **S5** (L): weapons/utilities/combat world + caps. Evidence: ported weapons + combat-replay tests green.
- **S6** (L): AI field (driver/tiers/overtake/director/standings) + raceSim/botDuel gates. Evidence: seeded 8-craft sim + balance gates green.

**Lane C — Controls/feel**
- **C0** (M): Input System maps + gamepad/keyboard paths + rebind persistence; raw parity feel (old shaping) for baseline. Evidence: input-trace capture works; baseline maneuver bundle recorded (§6.4).
- **C1** (L): steering architecture (§6.3 layers 1–5) + `CraftTuning` SO + live tuning panel. Evidence: objective gates (overshoot/settle/envelope/jerk) vs C0 baseline; piloted session ≥4/5 on gamepad.
- **C2** (L): touch scheme (slider + tilt option + buttons + haptics + safe areas). Evidence: piloted touch session ≥4/5 on min-spec + ProMotion devices; captain session scheduled.
- **C3** (M): chase camera port + yaw-smoothing budget + FOV/shake retune vs motion blur. Evidence: A/B captures; reduced-motion parity.

**Lane V — Visual/asset program** (V0 after P0; V1+ need P1 track in)
- **V0** (M): verification harness (showcase scene, Gate A/B scripts, manifest v2 schema + coverage test) + import presets. Evidence: harness runs on one existing ship raw.
- **V1** (L): **Ships wave** — 8 heroes from raw 4k (re-fetch/regen 3), LOD chains, material kit, AI field + ghosts use same prefabs; garage scene. Evidence: Gate A/B per ship; race capture with 8 real ships; §5.2 checklist.
- **V2** (L): **Structures wave** — Neon + Foundry kit modules (incl. tunnel arches), instanced placement from theme data. Evidence: Gate A/B per module; vista captures; budget capture per tier.
- **V3** (M): **Surface wave** — pads/strips/grid/finish/checkpoint gates + decal markings. Evidence: gameplay-readability captures (pickup/boost legible ≤ reaction distance); budget.
- **V4** (M): **Weapons/VFX wave** — D-category meshes + URP VFX (pooled). Evidence: combat stress capture, budget, photosensitivity check (`reducedFlashes` carries).
- **V5** (M): **Vistas wave** — skyboxes + far landmarks + rain/stars VFX rework. Evidence: theme captures both tracks.
- **V6** (L): **Lighting/GI wave** — bakes (lightmaps/APV/reflection probes), Volume profiles + exposure per theme, tier polish. Evidence: lever-table screenshots (audit §4 rows re-shot on device), scorecard re-run.

**Lane N — Net**
- **N0** (M): kz-n0-fix in existing repo (module bugs). Evidence: module tests + N0 rules suite.
- **N1** (L): C# SDK client + `SpacetimeMatchAdapter.cs` + hash handshake. Evidence: **first acceptance item = on-device iOS IL2CPP connectivity spike** (B.5 risk — SDK has no explicit iOS support statement); then connect/subscribe/publish loop vs local SpacetimeDB; handshake reject test.
- **N2** (L): online race E2E on device + reconnect lifecycle. Evidence: two-device session capture + server-side movement-limit checks green.

**Lane Q — Quality/stability**
- **Q0** (M): `Diag` suite — frame-series recorder, budget HUD, telemetry/evidence exporter, soak mode scaffold. Evidence: sample bundles from device.
- **Q1** (M): fall-through soak port + CI bounded gate wiring (with S1). Evidence: seeded soak matrix log, zero fall-through.
- **Q2** (L): device-matrix smoothness + crash-free certification (kz-smooth-g1 successor): 2 h soaks × 3 devices, frame-series on min-spec + Ultra, feel-rating sign-off. Evidence: full §8 bundle. **Gate for external TestFlight.**
- **R1** (M): App Store release proof (p6 successor): accessibility pass, license/credit sweep, store metadata, scorecard vs bar. **Gate for release.**

Critical path: P0→P1→S1→S2→{C1,V1}→…→Q2→R1. Everything else parallelizes. First "looks like the new game" build = P0+P1+S1+V1 (ships on real track in Unity) — deliberately early to de-risk the captain's fidelity judgment.

---

## 14. Tripo credit budget (~24,170 available; observed prices, official floor in parens)

Observed ledger prices (this account, v3.x, detailed texture): image_to_model ≈ 60, text_to_model ≈ 50 (official H3 sheet: 30–40 with detailed; the delta is options/model-version — budget on observed, celebrate surplus). Retry/curation multiplier ×1.5 on generation lines (Tripo variance on hard-surface kit modules is real; failed tasks refund).

| Wave | Items | Base cr | ×1.5 retry | Notes |
|---|---|---|---|---|
| V1 ships | re-fetch 3 via `conversion` (~10 ea) or regen (60 ea); contingency uplift regen ≤8 × 70; LOD via smart_low_poly ≤8 × 30 | 30–800 | 45–1,200 | Best case: raws re-download free/cheap; worst: full 8-ship regen at detailed |
| V2 structures | ~24 kit modules × 50 | 1,200 | 1,800 | Multiview/text mix; hero tunnel arch gets multiview (+10–20) |
| V3 surface | ~6 modules × 50 | 300 | 450 | |
| V4 weapons | ~8 meshes × 50 | 400 | 600 | |
| V5 vistas | ~10 landmarks × 50 + skybox source imagery (text-to-image 5–10 × ~20) | 600–700 | 900–1,050 | Skyboxes mostly via image-gen skill (non-Tripo) |
| V6 garage/support (H+G) | ~5 × 50 | 250 | 375 | |
| Texture/retexture passes | `texture_model` 10–20 × ~15 assets | 225 | 340 | Palette/livery alignment |
| **Program total** | | **≈3,005–3,875** | **≈4,510–5,815** | |

**Planning envelope: ≈5.4k–8.3k credits** (the ×1.5 range plus a 40% program contingency for captain-directed re-rolls after fidelity review) → **≥15.8k remaining** at completion; the previously-used 3,000-credit stop threshold is never approached. **Web fallback:** if the API errors/rate-limits (P1 gen = 5 parallel tasks; other = 10) or a hero asset needs manual curation, use Tripo Studio web with the same prompts/concepts, download GLB, and record `source: studio-web` + screenshot evidence in the manifest row (the ledger already has this fallback documented).

---

## 15. Risks & open questions

### Captain decisions needed (blocking marked ⛔)

| # | Question | Default if unanswered |
|---|---|---|
| Q1 | **Min-spec device floor** — A14 (iPhone 12, 2020) proposed | A14; ⛔ V6 tier tuning |
| Q2 | **Unity license tier** (Personal eligibility vs Pro) — revenue/org status is captain knowledge | ⛔ P0 |
| Q3 | Track-ribbon doctrine interpretation (§5.1 note): compiler geometry + generated surfacing = compliant? | Assume yes |
| Q4 | kz-funplay/PR #25: land as web baseline then freeze, or cancel now? | Land if green this week |
| Q5 | App identity: bundle id, display name, orientation (landscape-only proposed) | landscape-only; ⛔ P3 |
| Q6 | 120 Hz as Ultra-tier target vs locked-60 everywhere | 120 on Ultra |
| Q7 | Web build: freeze-as-demo (recommended) vs retire | Freeze |
| Q8 | Apple Developer Program + device matrix purchases (§10 checklist) | ⛔ P3/C2 |

### Top risks (mitigation in-plan)

1. **C# port fidelity drift** (feel/balance regressions) → parity fixtures + handling-metric goldens before any deliberate change (§4.2); replay goldens re-recorded per platform.
2. **PhysX reopens the fall-through class** → slab importer + CCD + ported gate/soak before V-waves scale content (§8.3, Q1 milestone).
3. **Tripo kit-module quality variance** (hard-surface consistency across 24 modules) → per-module Gate B against concept refs, ×1.5 retry budget, multiview generation for hero modules, Studio-web fallback (§14).
4. **Agent-driven Unity/Xcode CI fragility** → two-loop build design (§9.1), XcodeBuildMCP/bootstrap-ios, self-hosted Mac fallback; licensing activation tested at P0 (§10).
5. **Thermal throttling defeats 120 Hz** → governor demotes render scale first (§3.3/§3.4); 120 is a tier target, never a promise; series evidence catches it (§8.1).
6. **Scene-file merge conflicts across parallel lanes** → additive scenes per feature area + prefab-first workflow + YAML smart merge (§9.3).
7. **App Review surprises** → plain racing game, no UGC/gambling; keep test hooks stripped in release (§9.5); low residual risk.
8. **Scope gravity** (port + visual overhaul + multiplayer at once) → the §13 critical path front-loads "looks like the new game" (P1+S1+V1) so fidelity judgment happens before long-tail systems ports.
9. **Apple SDK treadmill** → App Store uploads already require Xcode 26/iOS 26 SDK (since Apr 2026), and Xcode 26.4+ requires **macOS Tahoe 26.2+** — the build Mac's OS is a hard dependency; expect an Xcode 27 mandate ~spring 2027. Mitigation: the self-hosted runner is owner-controlled; §10 checklist #2 pins it.
10. **Unity Personal in CI has sharp edges** → CLI `-serial` activation is Pro-only; Personal activates via Hub sign-in per machine (clean on the self-hosted Mac); hosted GameCI `.ulf` flow is community-standard but not formally blessed. Mitigation: self-hosted primary lane (§9.2); budget a Pro seat if the entity crosses $200K anyway.
11. **SpacetimeDB SDK on iOS unverified** → no explicit iOS statement in SDK docs and WebGL needed dedicated fixes as recently as v2.3.0; N1's first acceptance item is the on-device IL2CPP connectivity spike, scheduled before any client work stacks on it.
12. **LFS bandwidth burn** → Actions LFS pulls count against the 10 GiB/mo free bandwidth; CI caches LFS objects from day one; move to the Team plan (250 GiB) when the art volume demands (§9.3).

---

## 16. Rejected alternatives

| Alternative | Verdict | Rationale (evidence: Appendix B) |
|---|---|---|
| **Stay on three.js and push WebGPU/TSL** (pre-pivot §2 recommendation) | Rejected by captain platform decision | The research stands: it was viable for a *web* ceiling (TSL post stack TRAA/GTAO/SSR, shipped WebGPU showcases), and it proved the old look was self-imposed. Superseded by the native-fidelity + distribution decision; its artifacts (B.1/B.2) remain the web-freeze reference |
| **Babylon.js migration** (web) | Rejected | Real WebGL2 feature lead (IBL shadows/area lights/motion blur/Frame Graph) but: ~10k-LOC R3F rewrite to a thinner ecosystem, left-handed default vs the RH-math determinism contract, Havok-default physics invalidating tuned feel, WebGPU wins gated on static-scene snapshot tricks, and no shipped AAA-visual racer evidence (B.1 [3,21,24,48–51,53a,54,70–74]) |
| **PlayCanvas migration** (web) | Rejected | WebGPU still beta; no meshopt loader (engine issues #2630/#2636 open — breaks existing assets); post stack lacks motion blur; 2025–26 engine investment visibly in Gaussian splatting; proprietary SaaS editor with private-project lock-in; thin first-party React layer (B.1 [4,9,18–19,31–32,42–45,52]) |
| **Unreal Engine (mobile)** | Not evaluated deeply — captain chose Unity | Would re-open: 5% royalty regime, heavier iOS footprint, C++ toolchain for an agent team; no re-litigation per instruction |
| **Godot iOS** | Not evaluated deeply — captain chose Unity | Mobile 3D fidelity/toolchain maturity below the stated bar; same no-re-litigation note |
| **HDRP** | Rejected | Not supported on iOS; URP is Unity's mobile pipeline (§3.1, B.4) |
| **Unity Built-in Render Pipeline** | Rejected | Legacy; lacks Forward+/Render Graph/STP/APV that the lever table needs (B.4) |
| **DOTS/ECS + Unity Physics** | Rejected for v1 | Cross-platform determinism is beyond the documented same-build replay scope; ECS rewrite cost dwarfs its benefit at 8 craft; revisit only if server-authoritative rollback netcode ever demands it |
| **PhysX WheelCollider / vehicle SDK** | Rejected | Discards the tuned hover-craft model (raycast suspension + custom grip); §4.4 keeps our math |
| **Porting the track compiler to C#** | Rejected | Artifact-interchange keeps one authoring authority, byte-identical hashes, and the module data path; a second compiler = drift risk with zero player value (§4.1) |
| **Monorepo (Unity inside k-zero)** | Rejected | LFS churn + different CI/runners/review artifacts poison the existing repo; §9.3 |
| **Continue web meshopt/KTX2 optimization (fixed flags)** | Superseded | The safe recipe exists (B.3) and is recorded for the frozen web build, but the app path deletes the stage entirely (§5.2) |
| **Cross-play web↔app at launch** | Rejected (scope) | Frozen client vs live module drift; hash handshake makes stale clients fail clean instead (§11) |

---

## Appendix A — Evidence index

- **Forensic audit:** `/Users/leebarry/firstmate/data/kz-visaudit-v7/report.md` + `screenshots/`, `gifs/`, `evidence/` (glb-stats.csv, inspect dumps, code excerpts). Headline captures: `gifs/race-ai-box-silhouettes.gif`, `screenshots/foundry-drive-3.png` (tunnel boxes), `evidence/glb-inspect-raw-vs-opt.txt` (i8 normals).
- **Repo file:line map (this draft's own reads):** renderer `src/game/Scene.tsx:204-286`; optimizer `scripts/optimize-assets.mjs:87-95,318`; LOD/silhouette `src/game/craft/craftMeshes.tsx:222-234,298-310`; AI boxes `src/game/craft/PlayerCraft.tsx:1256-1258`; non-uniform scale `src/game/craft/craftLod.ts:32-51`; steering `src/game/craft/{steerMapping.ts:10-52, inputSampling.ts:221-280, craftController.ts:440-529, tuning.ts:177-245}`; materials `src/game/visuals/materials.ts:12-105`; budget overlay `src/game/visuals/RenderBudgetOverlay.tsx:20-40`; measured budgets `docs/asset-overhaul-budget.md`; credits ledger `public/assets/PROVENANCE.md`; queue `~/firstmate/data/backlog.md`.
- **This draft's working notes:** scratchpad `findings.md` (session-local).

## Appendix B — Research citations

*(B.1–B.3 were compiled pre-pivot and remain the evidence base for §16, §1.2, §5.2 and §14. B.4–B.5 are the Unity annexes.)*

*(B.1–B.3 verbatim from the pre-pivot research agents; B.4–B.5 from the Unity agents.)*

## B.1 Engine-decision annex citations (agent: engine alternatives)
[1] threejs.org/manual/en/webgpurenderer (live, mid-2026) · [2] threejs.org/manual/en/webgpu-postprocessing · [3] blogs.windows.com/windowsdeveloper/2025/03/27/announcing-babylon-js-8-0/ (2025-03-27) · [4] developer.playcanvas.com/user-manual/graphics/ ("WebGPU (Beta)") · [5] github.com/playcanvas/engine/releases/tag/v2.9.0 (2025-07-03) · [6] vr.org/articles/webgpu-baseline-2026-three-js-webxr-default (2026-05-06) · [7] youngju.dev WebGPU/WebGL 2026 deep dive (2026-05-16; contains a wrong Snap date — cross-checked) · [8] doc.babylonjs.com WebGPU docs · [9] blog.playcanvas.com/new-in-supersplat-webgpu-and-streaming-bring-huge-performance-wins/ (2026-06-03) · [10] forum.playcanvas.com/t/engine-v2-19-0/42321 (2026-05-28) · [11] threejs.org/manual/en/webgpu-postprocessing + examples/webgpu_postprocessing_traa.html · [12] github.com/mrdoob/three.js/pull/31576 (SSR perf, 2025-08-05) · [13] github.com/mrdoob/three.js/pull/31421 (TRAANode, r179) · [14] github.com/mrdoob/three.js/pull/33663 (GTAO improvements, 2026-06) · [14a] github.com/mrdoob/three.js/pull/31839 (SSGINode) · [15] doc.babylonjs.com defaultRenderingPipeline · [16] BabylonJS/Documentation taaRenderingPipeline.md · [17] doc.babylonjs.com SSRRenderingPipeline + SSAORenderPipeline + motion blur · [18] developer.playcanvas.com/user-manual/graphics/posteffects/cameraframe/ · [19] api.playcanvas.com/engine/classes/CameraFrame.html (v2.20.6) · [20] three.js r184 notes (LightProbeGrid, 2026-04-16) · [21] blogs.windows.com/windowsdeveloper/2026/03/26/announcing-babylon-js-9-0/ (2026-03-26) · [22] forum.babylonjs.com/t/frame-graph-v1-0-is-now-live/62163 (2026-01-20) · [23] github.com/mrdoob/three.js/releases (r185, 2026-07-01) · [24] doc.babylonjs.com webGPUSnapshotRendering + PR #15676 (2024-10-07) · [25] radiancefields.com/supersplat-ships-compute-based-webgpu-rendering-and-automatic-streamed-lod (2026-06-03) · [26] blogs.windows.com part-3-babylon-js-9-0-openpbr (2026-04-02) · [27] doc.babylonjs.com/features/featuresDeepDive/importers/glTF (Draco/meshopt/KTX2 table) · [28] github.com/playcanvas/engine/pull/2006 (Draco, 2020) · [29] developer.playcanvas.com editor import-pipeline docs · [30] github.com/playcanvas/engine/pull/3380 (KTX2) · [31] github.com/playcanvas/engine/issues/2630 (meshopt, open) · [32] github.com/playcanvas/engine/issues/2636 (quantization, open) · [33] abratabia.com/game-physics/ (2026-06-12) · [34] github.com/mikemainguy/rapierphysicsplugin (2026) · [35] doc.babylonjs.com usingHavok · [36] developer.playcanvas.com physics/ammo-alternatives · [37] github.com/pmndrs/react-three-fiber/releases/tag/v9.0.0 (2025-02-19) · [38] r3f.docs.pmnd.rs/tutorials/v9-migration-guide · [39] utsubo.com/blog/threejs-2026-what-changed (2026-01-10; vendor, date errors noted) · [40] github.com/brianzinn/react-babylonjs (v4.0.2, 2026-06-02) · [41] npmjs.com/package/react-babylonjs · [42] npmjs.com/package/@playcanvas/react (0.11.5, 2026-06-21) · [43] blog.playcanvas.com/declarative-3d-with-playcanvas-react/ (2025-01-14) · [44] playcanvas.com/plans · [45] developer.playcanvas.com billing · [46] arstechnica.com slow-roads-offers-a-chill-endless-driving-experience (2022-10-24) · [47] web.dev/case-studies/slow-roads (2023-04-11) · [48] theprovince.com/entertainment/shell-shockers-game-bc-developer (2025-08-25) · [49] webgpu.com/showcase/shell-shockers-babylonjs-browser-fps/ (2026-04-10) · [50] forum.babylonjs.com Wizard Masters (2025-03-21) · [51] forum.babylonjs.com Birdtown (2025-04-03) · [52] forum.playcanvas.com/t/showcase-venge-io/13609 + webgamer.io/en/g/venge-io · [53] forum.playcanvas.com Venge map editor (2021-08) · [53a] forum.babylonjs.com/t/why-webgpu-backend-is-slower/24091 (2021-09) · [54] forum.babylonjs.com/t/webgpu-vs-webgl-engines-first-impressions-after-usage/56078 (2025-01-20) · [55] gamedevjs.com Space Intruders Alliance (2025-03-27) · [56] developer.playcanvas.com engine/migrations · [57] github.com/playcanvas/engine/releases/tag/v2.4.0 (2025-01-15) · [58] v2.11.0 (2025-09-03) · [59] forum.playcanvas.com/t/engine-v2-20-0/42387 (2026-06-23) · [60] techcrunch.com/2018/03/23/snap-reportedly-buys-its-own-3d-game-engine/ · [61] gamedeveloper.com Snapchat acquires PlayCanvas (2018-03-26) · [62] utsubo.com/blog/webgpu-threejs-migration-guide (2026-01-21) · [63] github.com/mrdoob/three.js/pull/33843 (SSR denoiser, 2026-06-19) · [64] github.com/mrdoob/three.js/issues/30560 (2025-02-19, open through r183) · [65] github.com/mrdoob/three.js/issues/32675 (2026-01-06) · [66] github.com/mrdoob/three.js/issues/33194 (2026-03-17) · [67] github.com/mrdoob/three.js/issues/29580 (2024-10-07) · [68] github.com/mrdoob/three.js/issues/31055 (2025-05-06) · [69] utsubo.com (vendor claim) · [70] diva-portal.org/smash/get/diva2:1874949/FULLTEXT01.pdf (2024) · [71] forum.playcanvas.com/t/solved-performance-gap-of-large-number-of-quads-with-babylon-js/36652 (2024-08) · [72] github.com/playcanvas/engine/issues/5700 (2023-09/10) · [73] forum.babylonjs.com/t/performance-issue-fps-drops-significantly/63196 (2026-04-17) · [74] forum.babylonjs.com/t/does-babylon-js-or-three-js-perform-better-with-more-meshes/7505 (2019-12) · [75] tympanus.net/codrops/2026/05/19/ shader-se webgpu-pipeline (2026-05-19) · [76] webgpu.com/showcase/ivress-utsubo-webgpu-story/ (2026-04-23) · [77] github.com/momentchan/false-earth + Codrops (2026-04-21) · [78] github.com/cortiz2894/hologram-particles (2026-05) · [79] webgpu.com/showcase/shining-webgpu-storybook/ (2026-07-06)

Key measured facts: k-zero coupling = 9,903 LOC .tsx; 14 files import @react-three/fiber|drei; 26 import three; 22 touch Rapier; 10 use @react-three/rapier; 12 non-component .ts import three math (incl compiler/frames.ts, inflate.ts, craftPhysics.ts, rapierCraftSim.ts, chaseCamera.ts). Babylon default LEFT-handed. WebGPU field support ~79% overall (Win 87 / mac 84 / iOS 82 / Linux 15) per web3dsurvey.

## B.2 Rendering-SOTA annex citations (agent: three.js AAA pipeline)
Versions: three r185 (2026-07-01); R3F v9.6.1 stable (2026-04-28), v10.0.0-alpha.1 (2026-01-17); postprocessing 6.39.2 / 7.0.0-beta.16 (WebGL-only, WebGPU deferred — issues #279/#643); @react-three/postprocessing 3.0.4 (dropped SSR + N8AO vendoring); drei v10 stable / v11 alpha WebGPU tracker #2658.
- WebGPURenderer manual: threejs.org/manual/en/webgpurenderer ("experimental state although maturity greatly improved"; WebGLRenderer maintained, no larger new features; automatic WebGL2 fallback; forceWebGL) · WebGL fallback node support: three #28957 · three.webgpu.js since r167 (2024-08-01).
- Browser: web.dev/blog/webgpu-supported-major-browsers (2025-11-25; Baseline Jan 2026; Safari 26 Sept 2025); web3dsurvey.com/webgpu (~79%); utsubo.com/blog/frontier-web-apis-2026-production-ready (2026-04-29).
- R3F: v9.0.0 release notes (async gl prop, extend(THREE)); v9 migration guide; v10.0.0-alpha.1 notes (state.renderer, useUniforms/useNodes/usePostProcessing).
- ShaderMaterial not on WebGPURenderer: three #26925; Maxime Heckel field-guide-to-tsl-and-webgpu (2025-10-14). drei MeshReflectorMaterial requires rewrite: drei #2361. SoftShadows WebGL-only (patches ShaderChunk): drei source softShadows.tsx.
- Tone mapping: discourse.threejs.org/t/tone-mapping-overview/75204 (2024-12); modelviewer.dev/examples/tone-mapping; AgX PR #27366 (r160); AgX low-contrast + AgXPunchy unmerged: PR #27618; Neutral PR #27668 (r162) + rename #27717 + WebGPU #28599; Khronos spec: github.com/KhronosGroup/ToneMapping PBR_Neutral; no CDL grading API (#27618); exposure examples: webgpu_lights_tiled (Neutral, exposure 5), webgpu_postprocessing_bloom_emissive (ACES + exposure GUI); Blender exposure mismatch #27362.
- HDR output: Chrome 129 WebGPU canvas toneMapping extended (developer.chrome.com/blog/new-in-webgpu-129, 2024-09); ccameron-chromium webgpu-hdr EXPLAINER; three r180 PR #29573 (outputType HalfFloatType + ExtendedSRGBColorSpace, WebGPU only; donmccurdy caveats #29656); discourse t/true-hdr-color-support/78370.
- HDRLoader rename r180; UltraHDRLoader r167.
- Post stacks: pmndrs postprocessing README (auto effect merging); v7 beta rewrite #419/#600 (open); realism-effects (0beqz): TRAA/MotionBlur/SSGI/HBAO/SSR, VelocityDepthNormalPass, perspective-only; N8AO README (halfRes 2-4x, ~1ms upscale, 8-64 samples, enableDebugMode lastTime); drcmda on pp vs jsm SSAO: discourse t/best-ssao 54284; TSL RenderPipeline rename r183 PR #32789 + docs/pages/RenderPipeline; MRT + UnsignedByteType demote: threejs.org/manual/en/webgpu-postprocessing.
- TRAA: TRAANode docs (requires MSAA off); PR #31421 (r179 rewrite; "brings framerate back to 60" vs MSAA at 5K); #31895 disocclusion (2025-09); #32296 depth motion factor (r182); #32319 Halton jitter; #32322 variance clipping ("much less smearing"); residual issue #31892.
- AO: GTAO best built-in: PR #27296/#27319 (Pixel 4a 60fps native once MSAA off); TSL ao() resolutionScale 0.5 + temporal: webgpu_postprocessing_ao example.
- Bloom: TSL bloom() emissive-MRT selective: webgpu_postprocessing_bloom_emissive example; per-object masks PR #28913; MRT per-attachment blending PR #32636 (2025-12); pmndrs mipmapBlur since 6.35 (#279).
- Motion blur: PR #29058 (r168; per-object opt-in velocity; skinned caveat); example webgpu_postprocessing_motion_blur.
- SSR: PR #29597 (r170, half-res default); #31576 (quality scalar; 29→52fps at q0.5, 2025-08; also WGSL-vs-GLSL loop perf + Chrome 133 fix); #31649 roughness mips; react-pp v3 removed SSR (compare v2.16.7...v3.0.4).
- CSM: three/addons csm/CSM.js (WebGL) + CSMShadowNode PR #29610 (r170) + docs/pages/CSM + webgpu_shadowmap_csm example (cascades, practical, fade; setupMaterial for WebGL variant); PCFSoft on WebGPU since r167; VSM built-in type.
- Baked: drei AccumulativeShadows docs ("zero performance impact after accumulation"); BakeShadows; ContactShadows (deepwiki drei 4.2-shadows); drcmda "all runtime shadows look fake" discourse t/61083; lightmap workflow discourse t/34924, t/25030, t/63910 (RGB lightMap vs aoMap; texture.channel r151+; flipY=false).
- DPR/governor: R3F scaling-performance docs (performance.regress, min/max/debounce); RFC #1070; discussion #2016 (current moves only on regress()); drei PerformanceMonitor source+docs (250ms x10 window, factor ±0.1, flipflops→onFallback, refresh-rate bounds); AdaptiveDpr #2052 (resolved = current × dpr max); PassNode.setResolutionScale PR #31697 (r181) + PassNode docs; FSR1Node + TAAU-too-blurry: issue #33359 (2026-04, webgpu_upscaling_fsr1); Slow Roads render-scale setting (neoteo coverage).
- Lighting: TiledLighting PR #29642 (1024 lights, Pixel 8 demo); ClusteredLighting PR #33406 (2026-04, Forward+, 32px×24 z-slices, 64/cluster, 1024 max, replaces tiled) + example rework PR #33803 (~1000 lights 120fps M2 Pro; z-slice far-plane caveat ~10fps).
- Named examples: Slow Roads web.dev case study (2023-04-11) + anslo.medium.com write-up (no dynamic shadows; pooling; corridor LOD; quality+render-scale settings); PolyTrack kodub.itch.io devlogs 624385 + 773067 (three r155, WASM physics); Mario Kart 3.js github Lunakepio; pmndrs/racing-game repo (store-driven dpr/shadows = tiers-as-state); phoboslab.org/log/2023/08/rewriting-wipeout (C→WASM, not three); webgpu_tsl_galaxy (Bruno Simon r167); Heckel TSL field guide (2025-10).

## B.3 Asset-pipeline-safety annex citations (agent: asset pipeline)
- gltf-transform CLI 4.4.1 optimize defaults (local --help dump): --compress meshopt + --meshopt-level high (FILTER, gltfpack -cc equiv); --simplify true --simplify-error 0.0001 --simplify-ratio 0; --weld/--join/--flatten/--palette/--prune true; --texture-compress auto; --texture-size 2048.
- SHIPPED EVIDENCE: gltf-transform inspect public/assets/ships/ship.glb → generator "glTF-Transform v4.4.1", EXT_meshopt_compression + KHR_mesh_quantization, NORMAL:i8_norm, POSITION:i16_norm, TEXCOORD_0:u16_norm, 12,434 verts / 15,572 tris, bbox ~1m.
- meshopt.ts hard-caps quantizeNormal min(x,8) at level high: github.com/donmccurdy/glTF-Transform packages/functions/src/meshopt.ts; QUANTIZE_DEFAULTS pos14/norm10/uv12: quantize.ts.
- 8-bit normal faceting + recommend -vn 12: meshoptimizer #632; zeux 16-bit normals for reflection fidelity: KhronosGroup/glTF #1670.
- Meshopt lossy-on-recompress warning: gltf-transform.dev/modules/extensions/classes/EXTMeshoptCompression ("compression should generally be the last stage").
- Simplify defaults: gltf-transform SimplifyOptions docs; sloppy mode seam destruction: meshoptimizer #71.
- Position snapping scene-global (gltfpack): meshoptimizer #466, #433; UV 12-bit tiling: #93; morph clamp bug #515 / glTF-Transform #1142 (fixed 3.8).
- v3→v4 lossless weld: glTF-Transform PR #1357.
- Draco vs meshopt: three.js PR #20508 (meshopt decoder ~1GB/s SIMD, 21KB raw/6KB gz); svilenkovic.com/3d/draco-vs-meshopt; discourse t/draco-animation/10945 (at ~20k tris Draco advantage insignificant, load worse); Needle engine docs default choices.
- Verification: gltf-transform.dev/cli (inspect, ktxfix); threejs-visual-qa repo; KhronosGroup/glTF-Render-Fidelity-Generator; glcheck (threshold 0.99); luma.gl SnapshotTestRunner docs; three e2e #16941; render normals-as-color + glossy pass advice (agent synthesis).
- Hausdorff: PyMeshLab discussions #34 (get_hausdorff_distance RMS/max/mean); meshlabstuff.blogspot.com 2010/01 metro tutorial; vcglib apps/metro.
- LOD: three LOD docs addLevel(mesh, distance, hysteresis) merged r147 PR #14566; alphaHash PR #24271 (donmccurdy use case #1 = LOD transitions); BatchedMesh LOD: webgl_batch_lod_bvh example + PR #31239 + github.com/agargaro/batched-mesh-extensions (addGeometryLOD; 10 geo × 500k instances × 5 LODs); meshopt shared vertex buffer LOD: #27980 (donmccurdy); octahedral impostors: discourse t/85735 (agargaro forest), Anderson Mancini R3F/WebGPU (100k @ 120fps, youtube JIMvWMFqFPA), shaderbits.com/blog/octahedral-impostors; geomorph skip consensus: discourse t/87453.
- KTX2: KHR_texture_basisu spec (ETC1S color / UASTC non-color normative note; multiple-of-4); KTXDeveloperGuide (ETC1S kills normal maps; bpp math UASTC 8bpp=1B/texel, ETC1S 4bpp=0.5B/texel; +33% mips); KTXArtistGuide (toktx recipes: etc1s clevel 4 qlevel 255; uastc quality 4 rdo_l .25 rdo_d 65536 zcmp 22 assign_oetf linear); gltf-transform uastc --slots normal/occlusion/metallicRoughness --level 4 --rdo --zstd 18 + etc1s --quality 255; GPU math: 1k PNG 5.6MB vs UASTC 1.4 vs ETC1S 0.7; 2k: 22.4/5.6/2.8; 8 ships (2k albedo ETC1S + 1k normal UASTC + 1k ORM UASTC) ≈ 45MB GPU vs ≈270MB uncompressed; Khronos lamp 13MB/96MB → 10MB/21MB.
- Tripo pricing (docs.tripo3d.ai/get-started/pricing.html + rate-limits; tripo3d.ai/api): $1 = 100 credits; H2/H3: text 10/20 (no-tex/tex), image 20/30, multiview 20/30; P1-20260311: 30/40, 40/50, 40/50; surcharges H2/H3: detailed texture +10, smart_low_poly +10, quad +5, parts +20; texture_model 10 (+10 detailed); segmentation 40; completion 50; smart low poly 30; prerig free; rig 25; retarget 10/anim; conversion 5 (+5 with params); text-to-image 5; multiview image 10. Failed tasks refund; credits never expire. H3 adaptive face counts up to 1.5M/2M tris — ALWAYS set face_limit or smart_low_poly (1k-20k) for game assets; quad=true → FBX + face_limit 10k default; P1 face_limit 48–20,000. Concurrency: P1 gen 5 parallel; other gen 10; rig/retarget 10; upload 10qps.


## B.4 Unity-rendering annex citations (agent: Unity iOS rendering)

**Versions/licensing:** unity.com/blog/unity-6-3-lts-is-now-available (2025-12-04; LTS→Dec 2027) · unity.com/releases/unity-6/support (6.0 LTS EOL Oct 2026) · discussions.unity.com 6.4 (2026-03-17) + 6.5 (2026-06-15; Built-in RP deprecated, supported through 6.7 LTS) · gamefromscratch.com/unity-7-is-dead (2025-12-02) + Unite 2025 roadmap (youtube rEKmARCIkSI): Unity 7 cancelled, CoreCLR/ECS incremental in 6.x · unity.com/blog/unity-is-canceling-the-runtime-fee (2024-09-12) · unity.com/products/pricing-updates (Pro **$2,310/yr** from Jan 12 2026) · unity.com/legal/editor-terms-of-service/software (2026-06-30: Personal ≤$200K; Pro required $200K–$25M) · support.unity.com 28114350573460 / 30322080156692 (tier table; $200K cap; splash optional).
**URP vs HDRP:** docs.unity3d.com/Manual/render-pipelines-feature-comparison.html (**iOS: URP ✅ HDRP ❌**) · HDRP System-Requirements @17.4 (no mobile) · docs.unity3d.com/Manual/metal-requirements-and-compatibility.html (HDRP "Yes (macOS only)"; Built-in deprecation note) · URP 17 what's-new (Render Graph; Compatibility Mode removed in 6.4 per UpgradeGuideUnity64) · WhatsNewUnity61 (Deferred+) · docs.unity3d.com/Manual/urp/gpu-resident-drawer.html + make-object-compatible (no MaterialPropertyBlock; MeshRenderer-only; animated cross-fade → static dither fallback) + gpu-culling.html · probevolumes-concept/-streaming + discussions.unity.com/t/1547559 (APV "made to work on mobile") · stp-upscaler.html (mobile compute; requires TAA; cheaper mobile path) · urp/anti-aliasing.html (MSAA cheap on tile GPUs caveat; FXAA mobile rec) · HDR output iOS 16+ (urp/post-processing/hdr-output.html) · 6000.3 URP notes (Kawase/Dual-filter bloom; secondary omitram.com 2025-12-05) · unity.com/demos/fantasy-kingdom (URP+GRD+GPU-occlusion+STP+APV, min iPhone 13).
**Apple/Metal:** discussions.unity.com/t/895745 (no native MetalFX plan; FSR/STP is Unity's answer) · assetstore 388280 (3rd-party MetalFX plugin) · DynamicResolution-introduction.html (iOS Metal via ScalableBufferManager + FrameTimingManager) · ScriptReference/Application-targetFrameRate @6000.3 (iOS default 30 fps; vSync ignored; divisor rule) · class-PlayerSettingsiOS @6000.5 ("Enable ProMotion Support") + developer.apple.com ProMotion doc · Rendering.OnDemandRendering · adaptiveperformance.apple@6.0 + supported-features (thermal levels, frame times, bottleneck; core → Editor module in 6.3) · metal-optimize.html (memoryless RTs) · texture-choose-format-by-platform (ASTC A8+; ASTC-HDR A13+) · TroubleShootingIPhone (<50% RAM jetsam) · Metal-Feature-Set-Tables.pdf (2026-05-21: A14=Apple7, A15/16=Apple8, A17 Pro/A18/M3/M4=Apple9) · apple.com newsroom 2023-09/2024-09 (A17 Pro/A18 HW RT) · 9to5mac + jilaxzone RAM-per-model lists.
**Racing bar:** digitalfoundry.net GRID Legends iOS (2025-02-08: ~630p/30, 40 fps mode on 120 Hz panels, SSR cut first, **20 Hz car cubemaps**, no MetalFX, HD textures on 8 GB) + apps.apple.com listing (device gates) · gamespress Feral (2024-10-07) · ea.com Real Racing 3 Under the Hood (2015) + destructoid (2013: Time-Shifted Multiplayer = recorded laps) · brownmonster.co.uk (Rush Rally 3 custom engine) · gdcvault.com/play/1023299 (CSR2 GDC 2016: Unity console-car visuals via PBR + static IBL) · wikipedia Mario Kart Tour (Unity).
**Techniques/physics:** lod/mesh-lod-* @6000.2 (Mesh LOD: import-time chains, shared vertex buffer, ≥256 tris, no material simplification; runtime threshold/bias) · configure-for-better-performance.html (probe blending/box projection costs, shadow knobs, LOD dither Bayer, LDR grading/LUT 16-32px) · unity.com/blog new-GI-in-Unity-6 (Enlighten deprecation path) · Physics.Simulate @6000.3 (Script mode; fixed step or non-deterministic; >0.03 s warning) · class-PhysicsManager @6000.4 (Enhanced Determinism) · uninomicon.com/physics_determinism (same-build/same-machine scope; world recreate) · discussions.unity.com/t/1667389 + github Kimbatt/unity-deterministic-physics (Unity Physics per-platform determinism only) · discussions.unity.com/t/5654 + gamedev.stackexchange q/49267 (ghost = recorded pose streams, not input replay) · integration-with-post-processing.html (mobile-friendly post list; Gaussian DoF).

## B.5 Unity-toolchain annex citations (agent: Unity iOS toolchain)

**Unity licensing/CI:** unity.com/products/pricing-updates + unity.com/products/unity-personal + editor-terms (2026-06-30) — Personal ≤$200K (contractor counts client finances), Pro $2,310/yr, §2.5 Unity Build Server excludes Personal · docs.unity3d.com EditorCommandLineArguments (batchmode/-executeMethod; -serial Pro-only) + ManagingYourUnityLicense @6000.6 (Personal = Hub sign-in; .alf flow deprecated) + stackoverflow 79858709 (Personal batchmode after Hub activation, 2026-01) · game.ci/docs/github/builder + /activation + /deployment/ios (unity-builder@v4; .ulf secret flow; two-stage iOS: ubuntu export → macOS xcodebuild+fastlane; workaround status github game-ci/documentation#408) · eosl.date/unity (6000.3.18f1 Jun 17 2026).
**Apple:** developer.apple.com/news/upcoming-requirements (2026-02-03: Xcode 26/iOS 26 SDK required for uploads since **2026-04-28**) · developer.apple.com/support/xcode + system-requirements (**Xcode 26.6 = 17F113**, Jun 25 2026; 26.4–26.6 need **macOS Tahoe 26.2+**) · developer.apple.com/programs/enroll (**$99/yr**) · ASC help (TestFlight: internal ≤100 instant, external ≤10,000 + Beta App Review, 6 submissions/24 h, 90-day builds; API keys under Users & Access → Integrations) · developing-metal-apps-that-run-in-simulator (Simulator ≈ MTLGPUFamily.apple2) · app-store/review/guidelines (games: completeness, loot-box odds, account deletion).
**CI/infra:** docs.github.com actions-runner-pricing (macOS $0.062/min std, $0.102 M2 Pro xlarge; ubuntu $0.006/min; 10× macOS burn of included minutes) + github.blog 2026-pricing-changes (Jan 21 2026: hosted cuts; **self-hosted platform fee postponed**) · support.unity.com Unity DevOps pricing Mar 2026 (Mac $0.07/min, 100 free Mac-min/mo) · codemagic.io/pricing + docs (M2 $0.095/min; **Unity flow requires Plus/Pro serial**) · fastlane releases (2.237.0, Jul 5 2026) + docs.fastlane.tools ASC-API-key auth · docs.github.com LFS billing (metered 2025: 10 GiB+10 GiB free; $0.07/GiB-mo; Team 250/250; Actions pulls count) · docs.unity3d.com SmartMerge @6000.6 + discussions.unity.com/t/1661546 (.gitattributes + unityyamlmerge driver).
**SpacetimeDB:** github clockworklabs/SpacetimeDB releases v2.3.0 (2026-05-27; Unity 6 WebGL dynCall fix) + v2.0.1 (Maincloud tiers) · spacetimedb.com/pricing (**Free 2,500 TeV/mo, idle auto-pause; Pro $25/mo = 100,000 TeV**) · docs /clients/c-sharp + /clients/codegen (`spacetime generate --lang csharp`; **C# client ↔ Rust/TypeScript module** officially supported) · nuget SpacetimeDB.ClientSDK 2.1.0 · UPM git `com.clockworklabs.spacetimedbsdk` · issues #278/#2699/#4959 (platform-gap history → iOS spike justified).
**Assets/tooling:** docs.unity3d.com Packages **com.unity.cloud.gltfast@6.19** (6.19.0 May 19 2026; editor+runtime; PBR→URP Lit; KTX via com.unity.cloud.ktx; EXT_meshopt via com.unity.meshopt.decompress ≥0.2.0-exp.1) · docs.tripo3d.ai/export/conversion.html (`convert_model` → FBX, texture_size ≤4096) · texture-choose-format-by-platform + TextureStreaming docs · UTF embedded since 1.5.1 (com.unity.test-framework@1.5/1.6) · getsentry/sentry-unity 4.6.0 (Jun 26 2026) + sentry.io/pricing (free Developer tier) · firebase release-notes/unity (Crashlytics 13.13.0) · Unity Cloud Diagnostics (10k reports/day included) · com.unity.memoryprofiler 1.1.12 · aws.amazon.com/device-farm/pricing ($0.17/device-min; 1,000 free min) · browserstack.com/pricing (App Live $39/mo) · github getsentry/XcodeBuildMCP (~77 tools).

---

## Appendix C — Skill / reference ledger (honest accounting)

| Skill / reference | Loaded? | Use in this plan |
|---|---|---|
| `threejs-aaa-graphics-builder` SKILL.md | **Yes** | Workflow framing; core rule ("authored forms before glow") shapes §5's generation-first order |
| ├ references/render-recipes.md | **Yes** | Lighting-stack layers, exposure-against-gameplay, bloom discipline → §3.2 rows |
| ├ references/technical-art.md | **Yes** | Material-kit roles (§5.4), render-budget doctrine + report format (§8.5), hero-vs-support surface framing (§5.1) |
| ├ references/visual-scorecard.md | **Yes** | Claim-gate design: scorecard + fresh-eyes + automatic failures → §5.6/§9.5 claim gates (engine-agnostic) |
| ├ references/implementation-blueprint.md | **Yes** | Hybrid asset pipeline + sourcing-ledger requirement → §5.1 table is that ledger, per-surface |
| ├ references/model-recipes.md | **Yes** | Minimum premium asset pass (hero + 3 hazards + 2 rewards + kit-of-8) sized the §5.1 category minimums |
| ├ shader-cookbook / checklists | Not loaded | three.js/GLSL-specific; superseded by the Unity pivot (URP shader work will consult Unity sources) |
| `threejs-3d-generator` references/api-notes.md | **Yes** | Tripo task types, model versions (v3.1-20260211), observed credits, rig/retarget sharp edges, `smart_low_poly`/`highpoly_to_lowpoly` → §5, §14 |
| `threejs-game-director` | **Not loaded — recorded honestly** | It orchestrates three.js *build execution*; the two loaded skills covered planning needs, and the platform pivot mooted its three.js-specific playbooks for the app path. The executing crew should not need it except for frozen-web touch-ups |
| `bootstrap-ios` skill + XcodeBuildMCP | Available, not loaded (planning scout) | Execution tooling for U0+ (§9.4, §10 #23); load at implementation time |
| Credential probe | **Not run** (no generation performed in this planning scout) | Key path documented (§5 intro, §10 #20); first V0 task runs the probe before any spend |

*Cross-review note for the co-draft fight: every §1 claim carries file:line into this worktree at `34ca048`; every §3/§9/§10 number carries a B.4/B.5 citation; §14 uses observed ledger prices over official price-sheet optimism deliberately. Attack those seams first.*
