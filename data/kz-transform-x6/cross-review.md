# K-ZERO Unity transformation: cross-review of `kz-transform-c2`

**Reviewer:** `kz-transform-x6` planning scout  
**Date:** 2026-07-13  
**Reviewed draft:** `/Users/leebarry/firstmate/data/kz-transform-c2/report.md`, all 656 lines / 14,429 words  
**Comparison draft:** `/Users/leebarry/firstmate/data/kz-transform-x6/report.md`  
**Code revision inspected:** `34ca04811a54`  
**Forensic ground truth:** `/Users/leebarry/firstmate/data/kz-visaudit-v7/report.md`

## 1. Verdict

The parallel draft is strong on Unity mobile rendering research, its short-term track-import strategy, touch-control product thinking, evidence capture, and its early on-device SpacetimeDB risk spike. It is not safe to adopt unchanged. Four of its choices contradict binding captain direction: it permits a 40 fps fallback, budgets visible sky/rain/UI outside Tripo, retains a public rejected web demo indefinitely, and treats a partial 5.4–8.3k-credit kit budget as total generated coverage. Several tool/version claims are also stale or unproven against this checkout.

The converged plan should:

1. Use **Unity 6.3 LTS 6000.3.19f1, URP, Metal, IL2CPP/ARM64**, with Forward as the default path and Forward+ earned only by a physical-device A/B on the highest tier.
2. Keep the **TypeScript track compiler as the sole authoring authority through native v1**, add a canonical language-neutral exporter/importer, and postpone a C# compiler port unless the dependency becomes demonstrably costly. This is the most important improvement C2 contributes over X6.
3. Keep the Unity project in this repository at `unity/KZero/` during migration so compiler, server, fixtures, and client changes can land atomically. A new repository can be reconsidered after contracts and native v1 stabilize.
4. Apply literal total coverage: every player-visible decorative form, including sky/vista geometry, weather/star cores, VFX cores, pads, track skin, and decorative UI art, traces to a Tripo task. Procedural geometry remains legal only when it is invisible authority such as colliders, sensors, probe volumes, or render machinery.
5. Authorize the C2 **5.4–8.3k figure only as an initial batch envelope**, not a completion forecast. Retain X6's **20.5k hard ceiling / 3.67k reserve**, reforecast after the first complete sector, and make every category fail closed against a renderer-to-provenance inventory.
6. Adopt C2's normalized touch/gamepad intent pipeline and PD yaw architecture, but correct the response-curve formula and use X6's stricter five-pilot, telemetry-backed acceptance gate.
7. Preserve 60 fps as a floor. Thermal adaptation removes quality features or disables 120 Hz; it never drops a supported configuration to 40 fps.
8. Use a dedicated Mac runner as the authoritative iOS CI path; treat Linux GameCI export as an optimization only after a pinned proof. Use current Unity Diagnostics or Sentry/Apple Organizer, not deprecated Cloud Diagnostics.

## 2. Review method and evidence

I read C2 from line 1 through 656, then checked disputed statements against the checkout, the visual audit, current GitHub state through `gh-axi`, the local Apple/Unity tool state, and primary vendor documentation.

Material commands and results:

```text
$ wc -l -w .../kz-transform-c2/report.md .../kz-transform-x6/report.md
656 14429 .../kz-transform-c2/report.md
647 13658 .../kz-transform-x6/report.md

$ git rev-parse --short=12 HEAD
34ca04811a54

$ gh-axi pr list --state open --limit 20
count: 0

$ gh-axi pr view 25
state: merged
merged: 2026-07-13T16:44:01Z

$ command/tool probes
Unity=missing; unityhub=missing; fastlane=missing; spacetime=missing
xcodebuild shim present, but active developer directory is CommandLineTools
xcrun simctl: unavailable
TRIPO_API_KEY/GEMINI_API_KEY/GOOGLE_API_KEY/ELEVENLABS_API_KEY: unset in process environment
```

Repository anchors:

- The current client is `spacetimedb: 2.6.0` at `package.json:34`; the server module requests `2.6.*` at `module/package.json:7`; checked-in bindings say CLI `2.6.1` at `src/net/bindings/index.ts:1-4`.
- Steering is binary at the source (`src/game/craft/inputSampling.ts:70-80`), linearly ramped at `:246-259`, then fed to torque/grip logic.
- The actual constants are attack `3.2`, max yaw `1.05`, lateral kill `0.92`, terminal steering authority `0.82`, and manual counter-steer multiplier `1.5` (`src/game/craft/tuning.ts:183-219,233-244`; `handlingVerbs.ts:113-141`).
- The web circuit uses Bloom only and DPR `[1,1.75]` (`src/game/Scene.tsx:253-260,281-285`). AI still renders `farOnly` (`src/game/craft/PlayerCraft.tsx:1255-1258`), and the far branch is a procedural silhouette (`src/game/craft/craftMeshes.tsx:293-310`).
- The optimizer still invokes the blanket `optimize --compress meshopt` path (`scripts/optimize-assets.mjs:89`), while provenance records 1k meshopt ships (`public/assets/PROVENANCE.md:14,82-84`).
- Audit evidence shows raw 4k/f32 versus runtime 1k/i8 normals (`kz-visaudit-v7/report.md:80-104`), the complete procedural violation inventory (`:114-164`), no shadows/AO and Bloom-only rendering (`:168-190`), and approximately 120 fps at only ~100k triangles (`:190,255-276`).

Current external facts used to challenge stale claims:

- Unity's official release page identifies **6000.3.19f1**, released 1 July 2026, and lists its current Metal/importer known issues: [Unity 6000.3.19f1](https://unity.com/releases/editor/whats-new/6000.3.19f1).
- Unity says old **Cloud Diagnostics is deprecated** and Unity 6.2+ uses the new Diagnostics service: [Unity migration notice](https://docs.unity.com/ugs/en-us/manual/cloud-diagnostics/manual/CloudDiagnostics/Migration).
- The official SpacetimeDB repository documents a standalone/Unity C# client, but the version actually compatible with this repo still must be proven rather than inferred from a marketing-level major number: [SpacetimeDB repository](https://github.com/clockworklabs/SpacetimeDB).

## 3. Agreements: what C2 gets right

### 3.1 Unity rendering direction

Both drafts correctly reject HDRP for iOS/iPadOS and select URP on Metal. C2's rendering table is particularly useful in translating the forensic audit's missing levers into Unity terms: a shadowed directional key, baked lighting/probes for static dressing, reflection probes, controlled bloom, tone mapping and per-theme grade, AO only on qualified tiers, dynamic resolution/upscaling, and a deliberately reduced 120 Hz profile. Its insistence that Simulator evidence is functional rather than performance evidence is also correct.

C2's use of APV, baked static environment light, one primary real-time directional, ASTC per map role, and per-tier post is a sound starting point. It also correctly treats HDR, reflections, shadow distance, and render scale as a coupled device budget rather than independent checkboxes.

### 3.2 Port discipline

C2 is right that design and deterministic architecture carry farther than renderer/physics implementation:

- fixed 60 Hz authority and ordered systems;
- quantized `InputIntent` and the ring-buffer boundary;
- seeded RNG, integer tick, same-build replay scope, and golden fixtures;
- versioned track/gameplay hash contracts;
- energy, inventory, weapons, utilities, AI policy/personalities, balance tables, and race rules;
- local-versus-online match authority and checkpoint/respawn containment.

Its cross-language fixture rule—each C# port lands with NUnit coverage and TS-exported input/expected-output vectors—is exactly the right way to prevent a visually impressive rewrite from silently changing game rules. Its recommendation to reproduce current steering before deliberately retuning it is good experimental hygiene: parity establishes the native baseline, then feel changes become attributable.

Most importantly, C2's decision to keep the **TS track compiler authoritative** at first is safer than X6's initial recommendation to port the compiler early. The existing compiler has unusually sharp invariants: RMF seam sign, quantization, gameplay/art hashes, generated module data, winding, and slab collision. A second compiler would create two authorities before the app has one complete native track. The converged plan should adopt C2 here.

### 3.3 Controls

C2 correctly decomposes “finicky” into source shaping, speed-dependent yaw target, a PD-like yaw controller, time-based lateral-grip decay, camera decoupling, and evidence. Its single normalized `InputIntent` for gamepad, virtual touch steering, tilt, and digital fallback preserves the existing player/AI/network boundary. The touch proposal—thumb-relative horizontal steering region, optional tilt, safe-area-aware action buttons, auto-throttle as an option, and haptics—is materially more complete than X6's control-layout detail and should be adopted.

Its target concept that a comparable physical flick should produce comparable screen-space behavior across speeds is an excellent feel invariant. The proposed 80–140 ms lateral time constant and materially reduced terminal yaw authority are reasonable hypotheses to test, not ship constants.

### 3.4 Multiplayer and stability

C2's week-one **on-device IL2CPP SpacetimeDB connectivity spike** is a strong risk reducer and should move onto the native foundation critical path. It is much cheaper to discover AOT/linker/transport incompatibility before porting match UI and online state. Its recorded-pose ghost recommendation is also appropriate because PhysX input replay is not cross-device determinism.

The frame recorder, p50/p95/p99 series, hitch counts, thermal timeline, memory series, two-hour physical-device soaks, background/foreground stress, controller disconnect, airplane-mode recovery, and real-device fall-through suites are all valuable. “Averages are not evidence” is correctly preserved.

### 3.5 Production/tool inventory

C2 provides a broad and practical inventory covering Unity licensing, iOS module, Xcode, Apple membership/signing, devices, glTF/FBX paths, LFS, CI, TestFlight, crash reporting, SpacetimeDB, and Apple agent tooling. Its separation of captain-owned enrollment/signing/account actions from crew-installable tools is directionally correct. X6 should retain the breadth of this table.

## 4. Disagreements and required corrections

### 4.1 URP tiers: keep the structure, change the floor and qualification policy

**Agreement:** URP, not HDRP; Quality 60 as the main experience; an optional Performance 120 mode; baked/static lighting plus a bounded real-time key; post and resolution scale by tier.

**Disagreement 1 — 40 fps is prohibited.** C2's thermal ladder explicitly ends `120→60→40` (`report.md:145`). GRID Legends shipping a 40 fps mode is interesting precedent but cannot override the captain's “60fps stays non-negotiable.” The correct response to thermal pressure is to reduce render scale, shadows, AO, reflection update cadence, density, and post; then disable 120 and hold 60. If the lowest allowed visual profile cannot hold 60 in the defined soak, that device/preset is unsupported. The sim remaining at 60 does not make a 40 fps presentation acceptable.

**Disagreement 2 — hard-coded A14 tiers are hypotheses, not support promises.** C2 declares `<A14 unsupported` and assigns detailed memory/render-scale budgets before a Unity vertical slice exists (`:139-145`). App Store configuration also does not make “A14” a clean universal deployment switch. Seed provisional cohorts, but qualify support using the same scene, physical-device frame series, thermal soak, jetsam headroom, and visual score. X6's qualification-based floor is safer. The captain decides the eventual support matrix after the first complete sector.

**Disagreement 3 — Forward+ is promoted too early.** C2 gives Forward+ to T2. K-ZERO's desired track corridor can be built primarily with baked emissive contribution, probes, and a small bounded real-time light set. Use regular Forward on Minimum and Quality. Only enable Forward+ on Ultra if an A/B shows a visible win and meets CPU/GPU, memory, thermal, and shader-variant gates. Deferred/Deferred+ remains rejected for this mobile target.

**Disagreement 4 — post techniques must earn their place.** TAA+STP can shimmer or ghost on thin rails, fast emissive silhouettes, particles, and high-contrast track edges. Motion blur and chromatic aberration can reduce racing readability and worsen motion sensitivity. Treat STP/TAA, SSAO, motion blur, and chromatic aberration as separately switchable experiments with reduced-motion parity and freeze-frame/motion captures. Bloom, ACES/LUT, contact grounding, and stable shadows are the base; effects are not the quality bar by themselves.

**Convergence:** use X6's exact version and Forward-first tier logic, C2's detailed per-feature tier candidates, and a physical qualification table rather than chip-name certainty. Quality 60 is default; Performance 120 is earned; no 40 tier exists.

### 4.2 Port sequencing: C2 wins on compiler authority; X6 wins on repository topology and oracle-first order

C2 labels compiled artifacts “data + protocol, zero rewrite” (`:157-161`). That is too strong. The checked-in artifacts are TypeScript modules under `src/game/track/compiled/*.artifact.ts`; Unity cannot consume them as-is. A canonical exporter, schema, validation rules, asset importer, generated collision meshes, and Unity runtime structures are new work. The fixed-point values and compatibility contract carry; the file representation does not.

The converged sequence should be:

1. Freeze the current TS golden oracle: fixed-step traces, gameplay hashes, compiled artifact semantic dumps, track-frame samples, grid/respawn poses, AI line/speed, weapon/balance vectors, and fall-through scenarios.
2. Create `unity/KZero/` and the C# assembly boundaries in the existing repository.
3. Add a canonical, versioned JSON/binary track export generated by the existing TS compiler. Keep `.artifact.ts` and module-data generation as current outputs.
4. Build a Unity importer and semantic comparator. Compare decoded fields and hashes, not C# serializer bytes.
5. Port pure sim/rules system by system with fixtures; rebuild Unity adapters, PhysX integration, input devices, presentation, and UI.
6. Reproduce native baseline steering, then land the feel workstream.
7. Port both tracks, AI/combat, and only then freeze the multiplayer schema.
8. Reconsider a C# compiler after native v1 only if keeping Node/TS authoring demonstrably blocks designers or CI.

C2 proposes a new `k-zero-app` repository while leaving compiler/server/web in the old repo (`:354-358`). That weakens its own single-PR milestone doctrine. Its P1 milestone explicitly requires an exporter PR in the old repo plus an importer in the new repo (`:453`), so it cannot be one atomic PR. It also makes module-schema, bindings, fixtures, and client changes cross-repository coordination problems. Unity LFS files can be isolated by path and ownership without “poisoning” history. Keep one repository during migration; split later only after stable published contracts justify the cost.

C2 also overstates “mechanical” portability. Pure rules can be translated closely, but PhysX damping, contact resolution, inertia, suspension, raycasts, float behavior, and lifecycle ordering are not Rapier equivalents. The **architecture and test intent** carry; physics results need bounded tolerances and re-derived feel evidence, not exact numeric promises across engines.

### 4.3 Asset doctrine and safe import: C2 has material coverage gaps

C2 correctly replaces ships, pads, structures, track dressing, projectiles, and vistas, but its own category table reintroduces prohibited exceptions:

- panoramic skybox from a non-Tripo image generator;
- rain/stars from generated sprite sheets;
- existing generated 2D UI texture art carried forward;
- a still-visible compiler ribbon surfaced with generated materials rather than a generated 3D surface system.

Those choices conflict with the binding “every visible thing is a real Tripo-generated 3D asset; no exceptions.” The audit itself counts stars/rain as violations (`kz-visaudit-v7/report.md:143,159`) and says the visible track surface is not a generated model (`:141-142`). The native plan must not use the audit's older “menu OK as 2D” judgement to dilute the captain's newer binding direction.

The safe interpretation is:

- Compiler ribbon, slab, sensors, occluders, probe volumes, and collision shapes may remain procedural only when invisible.
- Visible track lanes, shoulders, rails, wall panels, curbs, pads, strips, start grids, tunnels, and markings are modular Tripo meshes snapped to compiler frames.
- Sky is a generated 3D sky shell plus generated vista meshes. Weather and star presentation uses generated mesh families/cores; Unity particles/VFX Graph may instance, shade, move, and fade those assets but may not substitute visible primitive quads/spheres.
- Typography, masks, render targets, and layout are rendering mechanisms. Decorative UI frames, icons, ship portraits, buttons, and thematic imagery must derive from generated 3D assets and carry manifest lineage.

C2 is right to delete the web `optimize-assets.mjs` path from the native runtime, but “the corruption class ceases to exist” is too absolute. Unity still imports, compresses vertices, encodes ASTC textures, generates LODs, and may alter normals/tangents/materials. C2's Gate A checks “normals present” and `hero LOD0 >=12k`; neither detects i8-like precision loss. A mesh can contain normals and still be visibly quantized.

The converged import gate must record and assert:

- immutable raw GLB hash and Tripo task/config;
- imported vertex format/mesh-compression settings, normals/tangents, scale, bounds, topology, material/map mapping, color space, and texture overrides;
- raw-versus-prefab eight-angle turntables under neutral, glossy reflection, and normals-debug lighting;
- edge/SSIM or perceptual diff plus explicit glossy/highlight inspection;
- LOD transition video across approach/recede at racing speed, dither/hysteresis, silhouette deviation, and shadow continuity;
- physical-device shader/pink-material proof.

Use glTFast editor import and ASTC, with hero mesh/vertex compression off initially. A/B Unity Mesh LOD against Tripo low-poly derivatives on one ship. Automatic LODs remain descendants of a Tripo source only if the manifest records that lineage and the visual gate passes; heroes should not be bulk-simplified on faith. C2's 15–20k LOD0 and 12k minimum are current-source facts, not an AAA target ceiling. Let the complete-sector performance capture establish measured ship/scene budgets.

### 4.4 Credit budget: useful unit economics, invalid completion forecast

C2's observed per-task prices and retry model are useful. Its 5.4–8.3k estimate is not a credible total-coverage completion budget because the inventory is materially incomplete:

- only ~24 structure modules and six surface modules for two full circuits;
- only ten vista landmarks;
- no Tripo spend for the sky shell, rain/stars, sprite replacement, or decorative UI because those are assigned to non-Tripo generation/carryover;
- limited variant/retry allowance for projectiles, impacts, drops, track transitions, damaged/state variants, and LOD failures;
- no reconciliation against a renderer-walk inventory proving every visible renderer has a manifest claim.

Therefore the claim that at least 15.8k credits remain at completion is unsupported. The 8.3k figure can be an **initial authorization envelope** covering the first complete sector and highest-priority catalog batches. X6's 20.5k maximum is a **ceiling**, not a spending target. The merged budget control should be:

| Control | Converged rule |
|---|---|
| Starting ledger | Re-read actual balance and task ledger before spend; never assume the planning snapshot is current. |
| Phase 1 authorization | Up to 8.3k for one fully compliant vertical slice plus approved priority batches. |
| Reforecast point | After one ship family, one complete track sector, one pickup family, one weapon family, one vista/weather set, and importer/LOD retry data. |
| Program ceiling | 20.5k total without a new captain decision. |
| Protected reserve | 3.67k planned; automation hard-stops before the actual balance falls below 3.5k. |
| Category control | Per-category attempt/credit caps; no retry without recorded rejection reason; web fallback uses the same task ID/provenance ledger. |
| Completion claim | Renderer/prefab/scene walk reports zero unclaimed visible renderer and zero prohibited primitive/procedural fallback. |

This combines C2's empirical task economics with X6's complete-doctrine contingency and avoids treating reserve as permission to spend blindly.

### 4.5 Controls: adopt the architecture, correct the math and acceptance gate

C2's source-shaping formula is written `f(x)=x·|x|^k`, with `k≈1.6–2.0` (`:284`). That produces a total exponent of 2.6–3.0, much more aggressive around center than the prose implies. Use the unambiguous form `sign(x)·|x|^γ`, with a candidate `γ≈1.4–1.8`, then tune from traces and pilots. Do not freeze any number before the native baseline.

C2's steering diagnosis is otherwise sound. One nuance: `LATERAL_GRIP=0.92` removes 92% of lateral velocity on the next 60 Hz tick, so the visible update occurs after ~16.7 ms. Its equivalent continuous e-folding time is about `-1/60 / ln(0.08) = 6.6 ms`; calling it a “~6 ms time constant” is mathematically defensible, but calling the whole response a 6 ms snap can confuse discrete and continuous behavior. The conclusion—far too abrupt and frame-rate-semantic—is still correct.

The merged control pipeline should be:

`device sample → device calibration/deadzone → normalized curve → critically damped digital/analog filter → speed-sensitive yaw target → feed-forward + PD yaw controller → exponential lateral response → bounded assists → camera presentation`

Add X6's lifecycle rules: reset filters and held actions on pause/background/controller loss; time-stamp touch/gamepad samples; never change device state from network callbacks; expose raw/shaped/target/actual telemetry. Keep C2's touch layout and haptics.

C2's subjective gate—three sessions, `>=4/5` including captain—is too weak and weaker than the existing roadmap's five-tester intent. Adopt the stronger gate:

- at least five blind pilots on matched seeds across Neon and Foundry;
- separate adequate touch and gamepad coverage, not one pooled score;
- legacy/native-baseline/candidates presented without labels;
- median smoothness and confidence `>=4.5/5`, nobody below 4, at least 80% prefer the winner;
- wall contacts/km at least 30% better than untuned native baseline;
- median clean-lap regression no worse than 3%;
- captain separately signs “buttery”; raw input, target/actual yaw, lateral acceleration, path, device/build/seed, recording, and questionnaire attached.

### 4.6 SpacetimeDB: keep the spike, reject the proposed version pin

C2 says to use C# SDK 2.1.0 with a “current” 2.3.0 server (`:304,387-388`). This does not reconcile with the actual repository: the web client is 2.6.0, the TypeScript module requests 2.6.*, and bindings were generated with CLI 2.6.1. A Unity plan must not silently downgrade the client line or assume all 2.x combinations are equivalent.

Converged rule:

1. Keep the existing TypeScript module/server as authority initially.
2. Inventory its exact deployed CLI/server/module/client compatibility before adding Unity.
3. Pin the C# Unity SDK to a tested tag or commit compatible with that deployment; record package hash and notices.
4. Make the first network PR an on-device IL2CPP/linker/AOT connection, subscription, reducer, disconnect/background/reconnect, and two-device smoke.
5. Call the C# SDK's `FrameTick()` on the main thread. Convert callbacks into immutable tick-stamped inbox records and drain only at fixed-tick boundaries.
6. Store tokens in Keychain, regenerate bindings in CI, keep Solo at zero sockets, and preserve explicit local/online adapters.

C2's $25/month Maincloud Pro statement may be a reasonable planning allowance, but it should be a captain account/usage decision, not a technical prerequisite asserted before usage and current pricing are verified.

### 4.7 Stability metrics: correct the thresholds and API claim

C2's frame report counts hitches `>16.7 ms at 120` (`:315`). A 120 Hz frame budget is 8.33 ms; 16.67 ms is already a missed 120 frame and the 60 Hz budget. Report both:

- for Quality 60: frames `>16.67`, `>33.33`, `>50` ms plus p50/p95/p99 and longest hitch;
- for Performance 120: frames `>8.33`, `>16.67`, `>33.33` ms plus the same series and 1% low;
- CPU and GPU frame times separately, with thermal and memory timelines.

The named `Application.thermalState` API is not supported by the cited Unity API evidence. Use Adaptive Performance's Apple provider and, if necessary, a small native `NSProcessInfo.thermalState` bridge; name the actual wrapper in the plan. Do not invent an engine property.

C2's two-hour multi-device soaks, state cycling, fall-through sweeps, and zero-crash requirements should be retained. Add X6's per-track/per-tier matrix, jetsam/watchdog/pink-shader/audio/input/save failure definitions, and 120-to-60 mode-boundary tests. Quality changes occur at hysteretic safe boundaries, not continuously in corners.

### 4.8 Toolchain and CI: inventory breadth is good; readiness and current names are wrong

The C2 inventory should be amended as follows:

| C2 claim | Evidence-backed correction |
|---|---|
| Unity “latest” 6000.3.18f1 | Pin **6000.3.19f1** exactly. It released 1 July 2026. Upgrade only in isolated PRs because current known issues include a Metal command-buffer timeout and asset-import crash. |
| Unity/Xcode/Simulator agents marked ready | In this lab Unity/Hub, fastlane, and Spacetime CLI are missing; `xcodebuild` is only the CommandLineTools shim and `simctl` is unavailable. XcodeBuildMCP/bootstrap-ios being available to the organization does not equal a configured build host. Provisioning proof is milestone N0, not a green checkmark. |
| Existing Gemini and ElevenLabs keys | Neither is present in the process environment, no safe credential source is cited, and non-Tripo visual generation violates this program anyway. Audio can be handled separately only after its credential is proven. |
| Start with Unity Cloud Diagnostics | Legacy Cloud Diagnostics is deprecated. Use Unity 6.2+ **Diagnostics**, Apple Organizer/MetricKit, or Sentry, with captain approval for account, privacy, retention, and cost. |
| Spacetime 2.3 CLI/server + C# 2.1 | Reconcile to the repo's 2.6 module/client/bindings and prove C# compatibility on device before pinning. |
| Linux GameCI iOS export is the scale lane | Keep it experimental until exact Unity license activation, iOS module/container, artifact handoff, and matching Mac archive are proven. A dedicated self-hosted Mac remains authoritative. |
| `fastlane match` private cert repo is the default | Treat signing as an ADR: managed/automatic signing or protected CI keychain/ASC API key first; use `match` only if the captain accepts another encrypted secret repository and its rotation burden. |

The required-tools checklist must continue to flag captain-only items distinctly: Unity financial-tier attestation/account seats; Apple Developer membership and agreements; bundle/team IDs; App Store Connect role/API issuer-key; certificates/profiles or managed-signing policy; registered physical devices/trust; Mac runner and hardware; TestFlight external-review ownership; Tripo account/key/web fallback/top-up/credit ceiling; GitHub/LFS billing; Spacetime organization/hosting; diagnostics/privacy/analytics approvals; and public-web retirement authorization.

Crew-installable items remain: exact Unity/iOS module after seat access, packages/importers, Xcode/fastlane after Mac access, Git LFS/YAML merge, CI scripts, C# SDK/bindings, diagnostics integration, and agent Apple tooling. Every “installed” claim needs a version command and smoke artifact.

### 4.9 Web fate and roadmap

C2 keeps Vercel live indefinitely as a shareable demo at “zero marginal cost” (`:421-422`). Cost is not only a hosting invoice: a public rejected build carries security, dependency, multiplayer endpoint, support, brand, App Store confusion, and dual-QA costs. “Zero marginal cost” is also an unstable account fact not supported by this checkout.

Adopt staged retirement:

- freeze web features immediately;
- retain it privately or with a migration banner as behavioral oracle during porting;
- keep security-only fixes and the TypeScript compiler/module alive;
- after native v1 has 30 crash-free production days and required evidence retention, retire the public race build/endpoints;
- preserve a source tag, lockfile, immutable build, fixtures, audit evidence, and static landing page.

C2 also says PR #25 is open and leaves a decision about landing it (`:75,434,524`). Current `gh-axi` evidence shows it merged on 2026-07-13 and there are zero open PRs. Its output should be frozen as the web piloting baseline; the decision is closed.

Roadmap convergence:

- Current smooth-gate/N0 findings become native controls, lifecycle, network-containment, and telemetry gates; do not continue web tuning except to preserve the oracle.
- Existing AI core/personality/balance design ports before multiplayer schema freeze. The current scene only mounts live AI on Neon (`Scene.tsx:244-246`), so both tracks are a native acceptance condition.
- Energy, items, combat, respawn, fall recovery, race flow, audio design, and persistence carry as rule/spec/fixtures and rebuild as C#/Unity adapters.
- Web renderer/asset-optimizer/VFX implementation, primitive art backlog, R3F/Rapier presentation, Vercel feature work, and public web release tasks die.
- Spacetime TypeScript server work survives until a separate evidence-backed server-migration decision; no server rewrite is implied by the Unity pivot.

### 4.10 Milestone sizing and order

C2's six-lane structure is useful but some “single-PR” milestones are too large or cross-repository by definition. P1 spans old and new repositories; V1 imports all eight ships; V6 lights both themes; C1 implements five control layers at once. X6 also batches seven remaining ships too broadly. The merged plan should tighten increments:

1. **N0:** captain/tool preflight, exact versions, licensing/signing/runner ADRs; no gameplay.
2. **N1:** nested Unity shell, assemblies, package locks, blank Metal/IL2CPP device build.
3. **O1:** TS oracle/fixture/artifact export freeze.
4. **T0:** canonical TS exporter and schema only.
5. **T1:** Unity importer for one artifact slice; then full Neon; then Foundry as separate PRs.
6. **Q0:** frame/telemetry/evidence format before physics/feel claims.
7. **S0-series:** runtime clock/input ring/RNG; then energy/inventory; then weapons/utilities; then race/AI, each with fixtures.
8. **P0-series:** slab collision/suspension baseline; fall-through; respawn; state transitions, each separately evidenced.
9. **C0:** native untuned control baseline capture.
10. **C1:** shaping/filter/controller core; **C2:** touch/tilt/gamepad/haptics; **C3:** blind pilot tune/sign-off.
11. **A0:** provenance/import/diff/visible-renderer validator.
12. **A1:** one hero ship plus one completely generated track sector—the first honest visual/60 fps gate.
13. **A2-series:** ships in two-ship family batches, never an eight-ship bulk PR.
14. **A3-series:** pads/strips/grids, then VFX core families, then structures by track, then full visible surface by track, then sky/weather/UI decoration.
15. **R-series:** URP base lighting; shadows/contact; probes/APV; tiered post; each with physical-device A/B.
16. **NET0:** on-device SDK spike; **NET1:** adapters/inbox/Keychain; **NET2:** authoritative multiplayer flow.
17. **Q-series:** crash/fall soaks, min-tier qualification, TestFlight BRB, release evidence.
18. **W1:** public web retirement only after the production gate.

This preserves parallel ownership: `Sim`, `Track`, `Presentation`, `Controls`, `Net`, `Meta/UI`, `Diag/Build`, and category-scoped art folders/manifest shards. Only the release owner touches signing/build profiles; only compiler owners touch TS compiler semantics; additive prefabs/scenes prevent one giant scene conflict.

## 5. Claims refuted or materially qualified

| Parallel-draft claim | Finding | Disposition |
|---|---|---|
| PR #25 is open/in flight | `gh-axi pr view 25` reports **merged** at 2026-07-13T16:44:01Z; open PR count is zero. | Refuted; archive as baseline, remove open decision. |
| 6000.3.18f1 is the latest 6.3 LTS patch | Unity released **6000.3.19f1** on 2026-07-01. | Refuted; exact pin 6000.3.19f1. |
| C# SDK 2.1 / server 2.3 is the right current line | Checkout uses TS client 2.6.0, module 2.6.*, bindings CLI 2.6.1. | Refuted for this repo; compatibility spike chooses exact C# tag/commit. |
| A 40 fps thermal fallback is acceptable | Captain explicitly made 60 fps non-negotiable. | Refuted by binding requirement. |
| Skybox imagegen, VFX sprites, and carried 2D decoration satisfy coverage | Binding doctrine requires Tripo-generated 3D for every visible thing, and audit counts stars/rain/track surface as findings. | Refuted; replace with generated 3D lineage. |
| 5.4–8.3k completes the asset program and leaves >=15.8k | The estimate omits/under-counts complete surfaces, sky/weather/UI, variants, LOD/retry failures, and zero-claim inventory proof. | Unsupported; use as first authorization, 20.5k ceiling. |
| “Normals present” plus a 12k triangle floor catches i8-normal corruption | i8 normals are present and ~16k ships still failed visually. | Refuted by audit data; inspect vertex format and visual glossy/normal diffs. |
| Unity eliminates the asset-corruption class | Unity import/compression/LOD/ASTC can still alter fidelity. | Materially qualified; delete the known web pass but retain structural and visual gates. |
| Track artifact carries with zero rewrite | Its semantics carry; `.artifact.ts` needs exporter, schema, importer, and Unity structures. | Materially qualified. |
| New-repo P1 is a single PR | It explicitly changes exporter in old repo and importer in new repo. | Internally inconsistent; use one repo or two coordinated PRs. |
| `Application.thermalState` supplies the timeline | No cited/current UnityEngine API establishes this property. | Refuted as named; use Adaptive Performance Apple provider/native wrapper. |
| Cloud Diagnostics is the correct new-project default | Unity says it is deprecated in favor of Diagnostics on 6.2+. | Refuted; use current Diagnostics/Sentry/Apple tooling. |
| Unity/Xcode/Simulator/fastlane/Spacetime are agent-ready here | Local probe has no Unity/Hub, fastlane, Spacetime CLI, Xcode app, or simctl. | Refuted as present-tense readiness; provision and prove in N0/N1. |
| Three pilot sessions at 4/5 prove buttery controls | Too small and weaker than existing five-tester intent; no preference/efficiency guard. | Rejected; use five blind pilots and objective constraints. |
| Public Vercel demo is zero-marginal-cost indefinitely | Hosting account state is unverified and operational/brand/security cost is nonzero. | Rejected; freeze then retire after native production gate. |

## 6. What the converged plan should take from each draft

| Area | Adopt from C2 | Adopt from X6 | Final merged choice |
|---|---|---|---|
| Renderer | Detailed URP lever-to-tier map; APV/bakes/probes; mobile post candidates; Simulator caveat | Exact 6000.3.19f1; Forward-first; qualification-based tiers; strict 60/earned 120 | URP Forward baseline on Metal, Forward+ only proven Ultra; no 40; physical qualification. |
| Track/compiler | Keep TS compiler authoritative and import canonical output | Oracle-first freeze; nested repo; semantic cross-language comparisons | TS compiler remains sole v1 authority; canonical exporter/importer in one repo; defer C# compiler. |
| Sim port | Per-port NUnit + TS fixture discipline; baseline before steering change | Explicit system boundaries, `FrameTick` inbox, Keychain, lifecycle ordering | Pure rules port with fixtures; all engine adapters rebuilt and physically validated. |
| Assets | Category-by-category generation ledger; glTFast/FBX fallback; two-stage claim gate | Literal zero-exception coverage; invisible procedural authority only; stronger vertex/visual/LOD gates | Full Tripo renderer coverage with immutable raw lineage and fail-closed import/scene validation. |
| Credits | Observed task prices and retry arithmetic | 20.5k ceiling, 3.67k reserve, stop thresholds, broader inventory | 8.3k first authorization; reforecast after complete slice; 20.5k maximum. |
| Controls | Touch/tilt/gamepad product design; normalized intent; PD yaw/time-based grip; screen-space invariant | Lifecycle resets; five-pilot blind test; preference, contacts, and lap-time constraints | C2 architecture with corrected expo math and X6 acceptance gate. |
| Multiplayer | Week-one on-device IL2CPP spike; keep TS server | Actual repo-version reconciliation; main-thread `FrameTick`; immutable tick inbox; Keychain | Prove exact C# SDK against current 2.6-era deployment before stack-up. |
| Stability | Rich series/soak/state matrix | Correct 60/120 budgets, explicit failure taxonomy, per-tier/track matrices | Unified telemetry with >8.33 and >16.67 thresholds and zero-crash physical soaks. |
| Toolchain | Broad required-tools inventory and captain/crew ownership | Current names/versions, dedicated Mac authority, exact missing-tool evidence, privacy/billing checks | Corrected inventory; N0 proves every claimed tool/account; current Diagnostics. |
| Git/CI | LFS/YAML merge/assembly ownership and Mac-cost awareness | One-repo atomicity; self-hosted Mac primary; staged web retirement | Nested Unity monorepo through v1; reconsider split later. |
| Roadmap/web | Preserve compiler/server/oracle concepts | Freeze now, retire public web after 30 crash-free native days | Private/limited oracle during port; no permanent public rejected demo. |
| Milestones | Six parallel lanes and evidence bundles | Complete-sector A1 and tighter prerequisites | Smaller category/track/ship batches; instrumentation and risk spikes first. |

## 7. Final recommendation to firstmate

Use X6 as the structural base, but replace its early C# track-compiler port with C2's TS-authoritative export/import approach and import C2's better touch-control detail, mobile rendering feature map, empirical task pricing, on-device SDK spike, and tool-inventory breadth. Then correct C2's binding violations and stale facts using this review.

The first executable proof should not be “eight ships imported” or “a gray track at 120.” It should be one exact-pinned Unity device build containing one parity-checked native craft on one compiler-authored sector whose **entire visible skin is Tripo-generated**, with safe raw import, stable LOD transition, URP contact/shadow/grade, input and vehicle telemetry, no unintended fall-through, and a 60 fps physical-device frame-time series. That slice measures the real art cost, credit burn, thermal ceiling, input feel, and import safety before the program scales in parallel.

No implementation code was written for this cross-review.
