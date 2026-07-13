# K-ZERO native transformation plan — Unity on iOS/iPadOS

**Scout:** `kz-transform-x6`  
**Date:** 2026-07-13  
**Repository audited:** `/Users/leebarry/.treehouse/k-zero-7c110f/4/k-zero` at detached `34ca048`  
**Deliverable:** planning and evidence only; no implementation code, branch, push, or PR  
**Controlling direction:** replace the rejected browser presentation with a native Unity iOS/iPadOS application. Unity is a captain decision and is not re-litigated here.

## 0. Executive decision

Build K-ZERO as a nested Unity project at `unity/KZero/`, pinned to **Unity 6.3 LTS 6000.3.19f1**, using **URP on Metal, IL2CPP, ARM64**. Use URP Forward as the default mobile path and permit Forward+ only on a measured high tier. HDRP is rejected because Unity's compatibility table limits HDRP-on-Metal to macOS, while URP is supported on iOS. Unity 6.3 LTS is supported through December 2027; the selected patch was released 1 July 2026. Pin it exactly and upgrade only in an isolated, evidence-backed PR because that patch currently lists a Metal command-buffer-timeout freeze and an asset-importer crash among its known issues. [Unity 6 support policy](https://unity.com/releases/unity-6/support), [6000.3.19f1 release and known issues](https://unity.com/releases/editor/whats-new/6000.3.19f1), [Metal pipeline compatibility](https://docs.unity3d.com/6000.0/Documentation/Manual/metal-requirements-and-compatibility.html).

The native target is not a mechanical port:

- Preserve the proven **design contracts and test oracles**: 60 Hz ordered fixed-tick simulation, quantized input/replay ideas, the quantized and hashed track-artifact contract, track definitions and RMF algorithm, tuning/balance data, race and combat rules, AI personalities, and the SpacetimeDB server module.
- Rebuild all executable client code in C#: simulation, Unity Physics adapter, touch/gamepad input, UI, renderer, loading, persistence, iOS lifecycle, and SpacetimeDB C# client. Do not transpile TypeScript or embed JavaScript.
- Keep the existing TypeScript SpacetimeDB server during client parity. Rewriting server and client together would destroy the current behavioral oracle and multiply migration risk.
- Keep simulation at 60 ticks/s in every mode. Render at locked 60 by default; offer interpolated 120 Hz only on qualified ProMotion devices. Never lower the acceptance floor to 30 fps.
- Treat **every player-visible world object** as a real Tripo-generated 3D asset. Invisible physics colliders, triggers, editor gizmos, and screen-space optical effects are not visible world objects and may remain engine data/effects. Missing runtime art must block scene entry or fail validation—never reveal a primitive fallback.
- Freeze the public web build as a short-lived migration demo and behavioral oracle; retire its public race service after native v1 has been in production for 30 crash-free days. Do not maintain two feature-complete games.

This transformation is complete only when both tracks and all eight ships pass on the physical-device matrix with: zero provenance violations; real generated LODs for player, AI, and ghosts; no geometry-corruption or LOD-pop failures; captain-approved “buttery” touch and gamepad steering; zero fall-throughs in the defined stress suite; zero crashes/hangs/jetsams in release soaks; and a sustained 60 fps frame-time series under thermal load. “Looks AAA in the Editor” is not a gate.

## 1. What was examined and what the evidence says

### 1.1 Method

I read the current repo architecture and tests, the committed roadmap, the queued P4 convergence plan, and all 299 lines of the independent forensic report at `/Users/leebarry/firstmate/data/kz-visaudit-v7/report.md`. I inspected its 1080p screenshots/GIF evidence and source anchors. I also used the Ref planning/read-code guidance, the installed `threejs-game-director`, `threejs-aaa-graphics-builder`, and `threejs-3d-generator` skills to understand the rejected render/asset pipeline, then used `bootstrap-ios`, `no-mistakes`, and `running-bug-review-board` to define Apple setup, CI, device, and evidence gates.

The harness exposed Ref and it was used. It did **not** expose an Exa MCP server/tool after enumerating available MCP resources and tools; rather than invent an Exa result, I substituted current primary sources from Unity, Apple, SpacetimeDB, GitHub/GameCI, Khronos, and the tool vendors. This limitation does not affect the engine decision, which the captain has already made.

Representative evidence commands and outputs:

| Command/probe | Material output |
|---|---|
| `git status --short; git rev-parse --short HEAD` | Clean worktree; `34ca048`. |
| `rg -n 'dpr=|Bloom|farOnly|distances=|castShadow' src/game/Scene.tsx src/game/craft/craftMeshes.tsx` | Bloom-only post at `Scene.tsx:254`; DPR `[1,1.75]` at `:285`; `farOnly` and box geometry; LOD thresholds `[0,32,75]`; imported ship shadows forced off. |
| Geometry-tag inventory over `src/game` | 82 boxes, 8 circles, 8 cones, 17 cylinders, 2 octahedra, 3 planes, 2 rings, 8 spheres, and 3 toruses in visible game code. This corroborates the audit; it is not itself the final provenance test. |
| `@gltf-transform inspect` evidence from the forensic audit | Raw Tripo hero examples carry 4096² textures and float attributes; optimized runtime ships are 1k with i16 positions/i8 normals. Geometry is valid; blanket recompression amplified poor fidelity but was not the primary box-field failure. |
| Toolchain probe | No Unity/Hub, Xcode.app, `simctl`, XcodeBuildMCP, Git LFS, SpacetimeDB CLI, fastlane, or Firebase CLI installed. Homebrew and 1Password CLI exist. `xcodebuild` resolves only to Command Line Tools. |
| Safe credential-presence probe | `TRIPO_API_KEY` is set via 1Password; no secret was printed. The committed ledger reports 24,170 credits remaining. |

### 1.2 Ground truth that the native plan must correct

The forensic audit is definitive scope evidence:

- Seven AI opponents are deliberately rendered as `farOnly` procedural boxes; the player's far LOD also pops to a box at 75 m. See forensic report lines 59–76 and `src/game/craft/craftMeshes.tsx:207-310`.
- Raw 4k Tripo sources still exist for five hero ships, but runtime optimization reduces all ship textures to 1k and quantizes normals to i8. The blanket path is `scripts/optimize-assets.mjs:78-123`; the non-uniform normalization in `src/game/craft/craftLod.ts:32-50` adds distortion risk.
- Pickups/drops, boost/recharge/grid pads, projectile and impact meshes, shields/EMP, pylons, gantries, buildings, skyline structures, Foundry tunnel panels, stars, and rain are visible procedural primitives. `public/assets/PROVENANCE.md:136-154` explicitly labels many as “KEEP procedural,” contrary to the captain's doctrine.
- The circuit has no shadows or AO, imported ships do not cast/receive shadows, post is bloom only, and DPR is capped. The web build measured roughly 100k triangles at about 120 fps, so its “budget look” was a product decision, not demonstrated exhaustion of GPU headroom. See forensic report sections 4, 7, and 8.

The root cause is therefore not “meshopt randomly exploded the mesh.” The loudest failure is intentional primitive art and primitive LODs. The permanent fix is a fail-closed asset contract plus visual diffs, not swapping one compression flag while leaving boxes in the field.

### 1.3 Existing architecture worth preserving as specifications

| Contract in current repo | Evidence | Native treatment |
|---|---|---|
| Ordered, plain-data, fixed 60 Hz runtime | `src/game/runtime/GameRuntime.ts:55-143`; one driver in `src/game/runtime/FixedStepDriver.tsx` | Preserve system order, integer ticks, seeded RNG, input ring, gate/reset semantics in pure C#. Replace R3F/Rapier driver. |
| Versioned quantized track artifact | `src/game/track/compiler/artifactTypes.ts:1-29`, compiler directory, checked-in artifacts | Preserve schema intent, units, hashes, compiler/art-version distinction, RMF seam tests, and golden fixtures; implement compiler/runtime reader in C#. |
| Physics/controller separation | Pure `src/game/craft/craftController.ts`; `PlayerCraft.tsx` adapter | Preserve pure-controller boundary and rebuild a Unity Physics adapter. Re-tune; do not copy Rapier impulses blindly. |
| Pure rules for race, energy, items, combat, AI | `src/game/{energy,items,weapons,ai,balance}` and test suite | Port behavior through shared JSON fixtures and seeded replays, not line translation. |
| Match authority boundary | `src/net/matchAdapter.ts`, `module/src/rules.ts` | Recreate `IMatchAdapter` in C#; retain local vs online authority split and current server module first. |
| Same-build local replay determinism | AGENTS.md and golden snapshot tests | Preserve this scope. Do not claim PhysX bitwise determinism across Apple chips/OS/Unity patches. |

Approximately 21.6k lines in pure/runtime-oriented TypeScript directories and 27 current tests are useful **specification volume**, not directly portable binary/code volume. About 30 R3F/Three/Rapier-dependent files and all TSX presentation code are replacement scope.

## 2. Binding quality contract

### 2.1 Visual contract

“Forza Motorsport / GTA 5 / Spider-Man class” is used as the composition, material, density, lighting, contact, motion, and finish reference—not as a promise that a passively cooled phone will equal a current console's raw scene complexity. The mobile acceptance bar is nevertheless uncompromising:

1. Eight distinctive high-quality ships, each with generated near/mid/far geometry; AI and ghosts use the same real catalog.
2. Both tracks completely dressed with generated track skins, rails, barriers, tunnels, pads, signs, structures, props, and vista meshes. The invisible compiler ribbon remains gameplay authority under the art skin.
3. PBR materials with correct albedo/normal/metallic-roughness/AO treatment, IBL/reflection probes, contact shadows, baked lighting where stable, a shadowed hero/key light, AO, controlled bloom, filmic tone mapping, and track-specific grade.
4. No visible boxes/cards/spheres/points standing in for world objects at any distance. UI typography and the screen compositor are rendering mechanisms, not substitute art: every decorative HUD/menu frame, item/ship icon, and 3D UI motif must be a Tripo-generated mesh or a render of one. Optical post effects are allowed only around approved generated objects and may not replace the object itself.
5. No perceptible LOD silhouette pop in authored chase/replay cameras and no geometry/material regression from source to device build.

Every visual claim on a landing PR requires fixed-camera physical-device screenshots at defined locations, not only Editor shots. The final comparison set contains eight angles for each asset turntable, chase/replay frames for each LOD transition, and matched 1920×1080-or-higher reference compositions where the device supports capture.

### 2.2 Performance and stability contract

- **60 Hz is non-negotiable** on every supported device/track/ship combination. The normal quality tier gets a 16.67 ms frame; its physical-device 30-minute thermal soak must have CPU and GPU p95 no worse than 13.3 ms (20% headroom), controlled 1% low at least 60 fps, and zero game-caused frames above 33.3 ms after warm-up. Record p50/p95/p99/max, hitch count, thermal state, memory, and jetsam—not averages alone.
- **120 Hz is an earned optional mode**, not the baseline promise. It targets 8.33 ms with CPU/GPU p95 no worse than 6.7 ms and 1% low at least 116 fps over the same series. If the tier fails thermal qualification, expose Quality 60 only; never oscillate frame target continuously.
- Simulation remains exactly 60 ticks/s at either presentation rate. 120 Hz renders interpolated poses. Online authority, input quantization, AI, and rules do not execute twice as often.
- Release soaks require zero crash, hang, out-of-memory/jetsam, fall-through, corrupted asset, or stuck input. “Average 60” with repeated 30–50 ms spikes fails.

### 2.3 Universal landing gate

Every milestone PR below has the same non-waivable gate in addition to its row-specific acceptance:

1. `no-mistakes` result is **checks-passed** for the Unity-aware pipeline; the shared daemon is never restarted by a lane.
2. BRB auto-QA is separate from interactive triage and returns **YES**, with no open P0/P1.
3. Visual changes attach physical-device before/after screenshots/video; control changes attach raw/shaped/filtered input plus vehicle telemetry and pilot result; performance claims attach frame-time series and Metal/Unity profiler evidence.
4. EditMode/PlayMode tests, deterministic fixture checks, asset/provenance validator, iOS IL2CPP build, and affected physical-device smoke all pass.
5. The PR owns only its declared paths or coordinates an explicit integration window. No milestone bundles unrelated refactors.

## 3. Target Unity architecture

### 3.1 Repository layout and ownership boundaries

Keep the current web app and `module/` in place while creating a nested Unity project. This avoids a disruptive repository move and permits legacy tests to remain the oracle during parity.

```text
unity/KZero/
  Assets/KZero/
    Runtime/
      Simulation/          # pure C#, no MonoBehaviour/UnityEngine.Object
      Physics/             # Unity Physics/Rigidbody adapter and colliders
      Input/               # normalized intent, touch/gamepad adapters, telemetry
      Networking/Spacetime/# C# bindings, match adapter, connection lifecycle
      Presentation/
        Render/            # URP assets/features, lighting, quality tiers
        Camera/
        VFX/
        UI/
      Platform/iOS/        # lifecycle, Keychain, haptics, thermal/frame policy
    Editor/
      TrackCompiler/
      AssetPipeline/
      Build/
    Art/
      Ships/ Items/ Track/ Props/ VFX/ Vistas/
    Scenes/
    Tests/EditMode/ Tests/PlayMode/ Tests/Device/
  Packages/manifest.json
  ProjectSettings/ProjectVersion.txt
unity/SourceAssets/Tripo/   # immutable raw sources, Git LFS, never runtime-loaded
docs/native/                # ADRs, captures, scorecards, pilot and soak evidence
```

The initial assembly definitions are `KZero.Simulation`, `KZero.Physics.Unity`, `KZero.Input`, `KZero.Networking.Spacetime`, `KZero.Presentation.URP`, and editor/test assemblies. `KZero.Simulation` may depend on standard C# and a pinned Unity.Mathematics package, but not scenes, MonoBehaviours, UnityEngine Objects, rendering, input devices, or sockets. Do not introduce DOTS/ECS during the port; the current plain data-oriented design is already testable and its behavior is known.

One `GameLoopBehaviour` is the client orchestrator: sample device state, quantize/enqueue intent, process the ordered fixed tick, step/consume the physics adapter in a defined phase, publish a snapshot, then let render-rate presentation interpolate snapshots. No gameplay rule may hide in arbitrary `Update`, coroutines, animation events, particles, or network callbacks.

### 3.2 URP, Metal, and color pipeline

| Decision | Target | Rationale and gate |
|---|---|---|
| Pipeline | URP, RenderGraph enabled | HDRP-on-Metal is documented as macOS-only; URP is the supported native mobile route. |
| Rendering path | Forward on Minimum/Quality; Forward+ experimental on Ultra only | Unity recommends Forward for mobile/low-end and rates Forward/Forward+ low impact on mobile, while Deferred adds costly G-buffer passes and loses MSAA. Forward+ earns promotion only if its extra lights/probes win on physical devices. [URP path comparison](https://docs.unity3d.com/6000.0/Documentation/Manual/urp/rendering-paths-comparison.html). |
| API/backend | Metal only; IL2CPP ARM64 | Removes OpenGL fallback variability and tests the shipping backend. Development builds retain script debugging only in non-release profiles. |
| Working/output color | Linear lighting, HDR internal camera buffer, ACES tone mapping; calibrated exposure per track | Establish one end-to-end color contract. Color swatches and neutral material ball are regression references. Optional system HDR output is a later high-tier experiment, never required for v1. |
| Materials | URP Lit plus a small reviewed Shader Graph library | Canonical opaque, emissive, glass/energy, decal, dither-LOD, and VFX graphs; no imported one-off shader graph per Tripo file. Use SRP Batcher-compatible material properties. |
| IBL/GI | HDR environment lighting, reflection-probe volumes, baked lightmaps/probes for static structures; dynamic key/rim for racers | Delivers material response without an unbounded real-time light count. Track art and gameplay collider hashes remain separate. |
| Shadows | One shadowed directional/key light; 2–4 cascades by tier; soft shadows; baked static shadows; high-tier contact enhancement | Restores grounding missing in web. Ships, AI, near props, and structures cast/receive. Shadow distance/resolution are tiered and series-tested. |
| Post | SSAO on Quality/Ultra, controlled bloom, filmic grade/LUT, subtle vignette; SMAA or 4× MSAA baseline | TAA is off until a chase-camera ghosting test passes. Full-screen motion blur is rejected for racing clarity/photosensitivity; use generated mesh trails and per-object motion cues. |
| Transparencies | Strict overdraw budgets and coarse-to-fine VFX tiers | Energy shields/rain/impacts are likely fill-rate bottlenecks. Each effect has an opaque/mesh-first design and measured overdraw. |

### 3.3 Resolution, frame pacing, and device tiers

Do not equate native resolution with quality. Render scale, post, shadows, LODs, and texture budgets change as a coherent preset at a safe boundary (menu/lap load), not every frame. Dynamic resolution may respond to sustained pressure with hysteresis, but cannot mask a failing quality tier or produce visible oscillation.

| Tier | Qualification, finalized by measured device IDs | Default | Principal limits |
|---|---|---|---|
| Minimum | Oldest iPhone and iPad the captain elects to support | 60 fps, Forward, 0.75–0.85 render scale as needed | 2 shadow cascades/short distance, no SSAO or low SSAO, lower real-LOD thresholds, 512–1k world textures, conservative VFX/transparent cap. |
| Quality | Median supported 60 Hz phone/tablet | 60 fps, Forward, 0.9–1.0 render scale | 4× MSAA or SMAA, SSAO, 2–4 cascades, 1–2k textures, full generated geometry density. |
| Ultra/ProMotion | Qualified high-end Pro iPhone/iPad (provisionally A17 Pro+/M2+ until measurements) | User choice: Quality 60 or Performance 120 | Forward or measured Forward+, shorter post/shadow list at 120, 2k hero and selective 4k albedo only if memory/thermal gates pass. |

Apple requires apps to tolerate variable refresh and warns not to assume the requested rate will be delivered. Add `CADisableMinimumFrameDurationOnPhone=true` to unlock above-60 presentation on compatible iPhones; iPad Pro does not require that key. Test gradual and sudden refresh changes plus thermal throttling on real devices. [Apple ProMotion guidance](https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays), [Info.plist key](https://developer.apple.com/documentation/bundleresources/information-property-list/cadisableminimumframedurationonphone).

The support floor is a product choice, not something the renderer can infer from App Store chip exclusion. Until the captain decides it, bootstrap with one oldest OS-eligible iPhone and iPad, one median 60 Hz phone/tablet, and one ProMotion phone/tablet. Simulator coverage is for lifecycle/UI/build correctness only and is explicitly invalid for GPU, thermals, memory pressure, controller latency, haptics, or 60/120 acceptance.

## 4. Port strategy: preserve contracts, rebuild the client

### 4.1 What carries and what does not

| Area | Carries into native | Rebuilt in C# / Unity |
|---|---|---|
| Simulation | System order, fixed 60 Hz clock, tick IDs, seeded RNG design, racer-registration gate, pause/reset semantics, quantized intent schema, same-build replay scope, goldens as fixtures | All executable TS, driver, snapshots, event queues, serialization and C# tests. |
| Track compiler | Track definitions, RMF/parallel-transport algorithm, seam-twist sign, quantization scales, artifact/hash compatibility contract, AI line, spawn/checkpoint/respawn data, golden SVG/data references | C# editor compiler/importer and runtime artifact reader. Track collision/art builders use Unity meshes/colliders. |
| Craft | Target handling verbs, terminal speeds, boost/coast/airbrake/sideshift design, suspension baseline and metrics | Unity Rigidbody/PhysX forces, raycasts, collision detection, grip/yaw controller, all tuning after device pilots. Rapier values are starting hypotheses only. |
| Race/energy/items/combat | Integer energy economy, respawn timing/rules, catalog/roll tables, hit limits/immunity, weapon and utility semantics, seeded policy tests | Pure C# rules, stores, event streams, and presentation adapters. |
| AI | Rookie/Pro/Elite personalities, reaction/noise/conservatism parameters, overtake/director policy, `InputIntent` boundary, seeded race/bot scenarios | C# policy/race sim and live Unity-body sampler. Both tracks are mandatory before network schema freeze. |
| Multiplayer | TypeScript server module, reducer/rules intent, checkpoint and respawn authority, local/online adapter boundary | Generated C# bindings, Unity connection lifecycle, iOS token storage, fixed-tick inbox, UI/reconnect/background handling. |
| Presentation | Art direction, references, camera/feel targets, reduced-motion and reduced-flash requirements, audio assets/provenance where licensed | Three/R3F renderer, React HUD, browser persistence, WebAudio, weapon meshes/VFX, loading, camera and all iOS UI. |

### 4.2 Porting sequence and parity method

1. **Freeze an oracle.** Tag the web state, archive its exact package lock and optimized assets, export canonical JSON intents/snapshots/events for representative 600-tick and race scenarios, record tuning tables and track artifacts, and capture both audit failures and intended gameplay. Do this before changing shared schemas.
2. **Bootstrap native and CI.** Create the exact Unity project, assembly boundaries, URP/Metal profiles, package lock, iOS simulator/device build, Git LFS rules, batchmode tests, and signed CI path. No gameplay is ported into an unrepeatable editor-only project.
3. **Port pure rules red/green.** Feed identical JSON fixtures to TS and C# harnesses and compare tick-by-tick state/events. Port runtime/input/race/energy/inventory/combat in small assemblies; preserve integer/quantized values where they are part of the contract.
4. **Port the track compiler.** The C# compiler consumes the same definitions and must match quantized semantic fields and gameplay hash. Where serialization bytes differ by language, compare a canonical field stream and deliberately version the artifact rather than silently changing it.
5. **Rebuild physics and fall safety.** Implement Unity hover suspension, solid extruded track colliders, continuous collision where measured, surface alignment, respawn, and the controller. The existing Rapier implementation remains an oracle for verbs and envelopes, not force constants.
6. **Close controls in a gray-box native slice.** One ship, one sector, touch and gamepad, camera, telemetry, fall-through suite, and captain feel sign-off precede expensive art scale-up. Bad steering must not be hidden under new art.
7. **Build a render/asset vertical slice.** One raw 4k ship plus one fully skinned track sector must prove source import, canonical materials, three real LODs, shadows/AO/post, 60/120 tiers, and physical-device visual diff.
8. **Scale total coverage.** Complete ships/AI/ghosts, items/pads, weapons/VFX meshes, Neon, Foundry, props, structures, and vistas through independent asset batches.
9. **Port AI, then online.** Both-track eight-craft C# AI and combat fairness gates pass before the P4 schema is frozen. Add the C# Spacetime client against the existing TS server; postpone any server-language migration.
10. **Harden and release.** Streaming/thermal/memory work, fault injection, accessibility/photosensitivity, TestFlight cohorts, App Store metadata/privacy, and release soaks close the plan.

No milestone may call a semantic port complete merely because it compiles. It needs a checked-in fixture showing which legacy behavior matched, which intentionally changed, and why.

## 5. Total generated-asset transformation program

### 5.1 Doctrine as an enforceable contract

The new provenance validator recognizes **non-art render mechanics**, not exceptions for substitute art. Invisible colliders/triggers/nav or AI guides/editor gizmos have no renderer. Text glyph rasterization, the final screen compositor, volumetric/lens calculations, and renderer-generated shadow/light buffers are rendering operations, but any decorative shape or world-form they display still resolves to approved Tripo art. Optical glow/trails may surround an approved generated body but cannot replace it. A visible pickup, raindrop, star, trail body, shield emitter, UI frame/icon, tunnel rib, track panel, or distant structure is art and must resolve to a Tripo source record.

Each runtime prefab contains or references an `AssetProvenance` record. The build fails if a visible renderer lacks one, if the source SHA is missing, if a LOD points to an unapproved mesh, or if a “debug/fallback primitive” is active outside development-only scenes. Runtime load failure returns to a branded error/menu with telemetry; it never instantiates a box.

The generated-coverage scorecard is enumerated by catalog/scene, not by searching for Unity primitive class names. A generated GLB can contain simple shapes and still be legitimate; conversely, a custom procedural mesh would evade a name search. The authoritative count is `visible runtime renderer -> prefab GUID -> approved provenance/LOD record`, and the release count of missing or exempted world renderers must be zero.

### 5.2 Source-to-device pipeline

1. **Generate:** Tripo API is primary. Prompts specify consistent scale, pivot, forward/up axes, material intent, silhouette, hard-surface detail, no background/base, and the relevant ship/track family. API key remains in 1Password and is never logged or committed. Web is a documented outage/failure fallback only.
2. **Land immutable source:** save raw 4k GLB, preview, prompt/request settings, Tripo task ID, credit cost, license at generation time, timestamp, and SHA-256 under `unity/SourceAssets/Tripo/<category>/<asset-id>/`, tracked by Git LFS. Never overwrite a source; revisions get a new ID.
3. **Inspect before optimization:** reject NaN/Inf, degenerate or non-manifold catastrophes, missing/tiny UVs, inverted/zero normals, extreme bounds, embedded cameras/lights, unexpected animation, absent texture channels, implausible material count, or wrong pivot/orientation. Establish the neutral source turntable here.
4. **Import with glTFast:** pin `com.unity.cloud.gltfast` and import GLB in the Editor to native prefabs; do not runtime-load production art. glTFast supports Editor import and URP and is Apache 2.0. Include its required shader variants in device builds. [glTFast repository and import guidance](https://github.com/atteneder/glTFast).
5. **Canonicalize:** map source PBR to reviewed URP Lit/Shader Graph materials. Albedo/emissive use sRGB; normal, metallic, roughness, and AO are linear. Convert glTF metallic-roughness packing to Unity metallic/smoothness deliberately (`smoothness = 1 - roughness`) and validate channels—never accept a visually plausible but numerically wrong pack.
6. **Normalize safely:** set a common unit/pivot/axis in the asset build, apply a **uniform** scale, and bake it before collider/LOD generation. Do not repeat `craftLod.ts`'s per-axis bounds normalization. Author attachment sockets and broad collision proxy separately from render topology.
7. **Create real LODs:** request LOD1/LOD2 from Tripo or optimize an immutable Tripo mesh under the per-asset diff gate; every LOD therefore retains a Tripo source lineage. Preserve pivot, silhouette landmarks, material naming, and socket IDs. Use `LODGroup` screen-relative thresholds and 10–15% dither crossfade. AI and ghosts reference these same assets; no box/card or unrelated procedural far LOD exists.
8. **Compress only after proof:** source and near hero keep Model Importer Mesh Compression **Off** and vertex compression off for position/normal/tangent. Allow a per-asset LOD1/2 setting only after the visual-diff gate. “Optimize Mesh” index/vertex reordering is acceptable if it is topology-preserving and diff-clean. Unity's mesh compression changes vertex attributes materially; it is not a blanket safe switch. [Unity mesh-compression guidance](https://docs.unity3d.com/6000.0/Documentation/Manual/configure-mesh-compression.html).
9. **Build textures for iOS:** preserve the 4k source; import per-tier ASTC with mipmaps and streaming. Prefer ASTC 4×4 or 6×6 for hero normals/high-frequency masks, 6×6 or 8×8 for albedo/ORM where the diff permits. Unity, not a web KTX2 runtime path, produces the shipping Metal textures. KTX/KTX2 tools may inspect or preserve source encodings but are not a second runtime loader.
10. **Validate source vs import vs device:** render deterministic turntables and in-game cameras at each stage. Only then approve the prefab GUID in the manifest.

Unity mip streaming loads only the mips needed for the camera and can enforce a texture memory budget; camera cuts and spawn transitions must explicitly prefetch hero/track mips to avoid visible blur. [Unity texture streaming](https://docs.unity3d.com/6000.0/Documentation/Manual/TextureStreaming.html).

### 5.3 SAFE geometry and visual-diff gate

The permanent “polygate” prevention gate for every asset has four layers:

| Layer | Automated evidence | Human/BRB evidence | Failure action |
|---|---|---|---|
| Structural | Source/import mesh and submesh counts, triangle counts, finite attributes, bounds, pivot, UV occupancy, normal/tangent distribution, materials/textures, sockets, collider separation | Neutral gray and PBR turntable sanity | Reject import; never auto-repair source in place. |
| Image diff | Eight fixed orthographic/perspective angles at source-equivalent framing; silhouette mask IoU and edge-distance alarm; normal-lit and wireframe captures; material-channel swatches | Side-by-side source/import/LOD review at 100% and common mobile viewing scale | Adjust explicit import/LOD setting or regenerate. No threshold-only approval. |
| LOD motion | Scripted chase/replay fly-through records transition frame, projected size, screen-space silhouette delta, crossfade duration, texture residency | Real-device video at normal and half speed; no visible box, collapse, flash, or hue/roughness change | Move threshold/crossfade, repair corresponding LOD, or regenerate. |
| Device build | IL2CPP/Metal prefab resolution, shader-variant presence, ASTC texture dimensions/memory, no pink/missing material, shadow/IBL response | Fixed-camera phone and iPad screenshots in both track rigs | Block catalog/scene. Editor success cannot waive a device failure. |

Absolute automated thresholds are calibrated on the vertical slice and stored per asset family; they are alarms, not permission to ship. The source-to-LOD silhouette target should begin at IoU ≥0.98 for LOD1 and ≥0.94 for LOD2 at its actual transition projection, with no landmark edge displacement above two output pixels. Tighten or adjust only from evidence.

### 5.4 Category program and initial quality targets

Counts below are planning units, not permission to hide variants inside one record. The asset inventory milestone fixes final IDs before bulk generation.

| Visible category | Required generated coverage | Initial runtime target | Acceptance beyond the universal gate |
|---|---|---|---|
| 8 ships | 8 LOD0, 8 LOD1, 8 LOD2; shared player/AI/ghost catalog; generated damage/exhaust attachments where visible | LOD0 roughly 30–80k triangles subject to device proof; 2k PBR maps, selective 4k albedo on Ultra only; LOD1 ~45–60%, LOD2 ~15–25% as silhouette permits | All eight run together on both tracks; no `farOnly`; uniform-scale bounds; transition video; captain hero review. Reuse raw 4k sources where they pass rather than spending to recreate blindly. |
| Pickups/drops | Weapon/utility pickup bodies, drop containers, family rings/emitters, respawn state pieces | 1k–2k near maps; real mid/far meshes; pooled renderers | Recognizable by silhouette and color without primitive crystal; each catalog item maps to provenance; spawn/claim/respawn does not allocate or pop. |
| Pads/strips/grid | Pickup bases, boost pads/chevrons, recharge strips, start slots/grid/gate modules | Modular generated meshes conformed visually over invisible track triggers; 1k–2k near maps | Every authored socket on both tracks resolves; no z-fight with collision ribbon; readable at speed and in color-blind/reduced-flash modes. |
| Projectiles/impacts | Pulse bolts, arc emitters, mine, seeker, rail hardware/beam carrier, EMP wave emitter; shield/decoy/nanite/overdrive bodies; impact/debris meshes | Generated base meshes, pooled/instanced; optical glow/trails may be shader effects around them | Freeze-frame shows real form; overdraw and pool caps pass; effect remains legible with bloom/reduced flashes off. |
| Props/structures | Pylons, gantries, billboard frames, pit/grandstand families, Foundry industrial kit, Neon civic/space kit, tunnel ribs/panels, barriers, signs, service objects | Modular kits with near/mid/far generated meshes; GPU instancing/SRP Batcher only after material canonicalization | Both track fly-through inventories have zero missing renderer provenance; repetition breaks through variants/placement, not random procedural boxes. |
| Track surfaces | Generated modular road skin, curbs/rails/walls/edge machinery, seams, boost/recharge housings, start/finish | Invisible quantized ribbon and solid collider remain gameplay authority; generated art overlays it. 2k high-frequency near materials, 1k/512 distant; decals/vertex blends reviewed | No collider/art mismatch that changes racing line; no cracks/z-fight; gameplay hash unchanged for pure art; track art gets independent `artVersion`. |
| Skybox/vistas | Generated sky shell/planet/station silhouettes, skyline masses, distant structures; generated star/rain/droplet mesh families if visible as 3D objects | Layered vista meshes/IBL; distant generated LODs; optical fog/grade allowed | No point-cloud filler or giant primitive ring; horizon holds in chase/replay cameras; parallax and scale support track identity. |

Instancing is a rendering technique, not an asset exception: every instance still points to an approved generated mesh. GPU Resident Drawer/indirect paths are enabled only after physical-device series show a win and shader/material compatibility passes. Occlusion culling and additive scene streaming should be authored per track sector; do not make the whole track resident merely because the web build had headroom on a desktop browser.

### 5.5 Provenance manifest fields

Each source/revision record must contain at least:

- stable asset and revision ID, category, display name, visible use sites, owner/status;
- provider = Tripo, API or web path, account/workspace, task ID/URL, created timestamp;
- prompt/image input hashes, generation/model/settings, face/texture targets, credits charged, contemporaneous license/terms reference;
- raw GLB and texture SHA-256, dimensions, triangle/submesh/material counts, source coordinate/pivot notes;
- Unity package/editor version, importer version/settings, canonical material IDs, ASTC/mip/streaming settings, Model Importer compression settings;
- prefab GUID, LOD GUIDs and transition/crossfade thresholds, sockets/collision proxy IDs, bundle/addressable group if used;
- turntable and in-game evidence paths, automated diff metrics, BRB approval, approver/date;
- supersedes/superseded-by lineage and reason. No deletion breaks an old release's audit trail.

### 5.6 Tripo credit budget

The committed ledger reports 24,170 credits. Cap this program at **20,500**, preserving **3,670** as a protected reserve. Stop automation if the observed balance would fall below 3,500 or if a request's returned charge differs materially from the ledger assumption.

| Program | Ceiling | Intent |
|---|---:|---|
| Ships and real LOD regeneration | 2,300 | Repair/recreate only what the raw 4k set cannot supply; three real levels for eight families. |
| Pickups/drops | 1,600 | Item silhouettes, containers, variants. |
| Pads/strips/start grid | 1,200 | Modular floor hardware and gates. |
| Projectiles/impacts/utilities | 2,000 | Generated mesh cores plus controlled variants. |
| Track skin modules/rails/tunnels | 6,000 | Largest coverage class across two circuits. |
| Props/structures | 4,800 | Neon and Foundry kits, landmark repair/LODs. |
| Sky/vista meshes | 1,000 | Horizon, planet/station, distant structures and weather mesh families. |
| Regeneration contingency | 1,600 | Failed topology/material/LOD runs; captain review iterations. |
| **Total spend ceiling** | **20,500** | Leaves 3,670 from the reported balance. |

Every generation job predeclares an asset ID and maximum attempts. Daily ledger reconciliation compares Tripo task history, local manifest, and actual balance; discrepancies stop the queue. The web fallback is used only when API generation is unavailable or lacks a required function. A crew member must immediately download the result and manually record task URL, prompts/settings, actual credits, license, timestamp, hashes, and screenshots before the asset can enter Unity. A web download with unknown provenance cannot be “fixed later.”

## 6. Control-feel workstream

### 6.1 Evidence-based diagnosis of current twitchiness

The current code has a useful input ramp, but several coupled choices plausibly produce the captain's “too finicky / too responsive left and right” result:

- Keyboard steering is binary `-1/0/+1` in `src/game/craft/steerMapping.ts:9-13`; only steer/thrust have smoothing state (`inputSampling.ts:68`). The current attack is 3.2/s—full lock in roughly 0.3 s—and release is 5.5/s (`tuning.ts:183-219`).
- High-speed steering retains 82% of low-speed authority, so top-speed stability assistance is slight (`tuning.ts:216-219`, `craftController.ts:460-489`).
- Grip removes 92% of lateral velocity **per tick** and redirects 85% into forward speed (`tuning.ts:200-210`, `craftController.ts:425-457`). That aggressive velocity rewrite can make small yaw commands snap the trajectory rather than load progressively.
- Yaw has a hard angular-velocity rewrite at 1.05 rad/s (`craftController.ts:492-501`). It is a safety cap, but repeated contact with it can make response feel clipped rather than damped.
- Test overrides merge after smoothing (`inputSampling.ts:262-278`), so some automation can bypass the player shaping path. Existing steering unit tests prove ramp mechanics, not touch/gamepad feel, overshoot, path deviation, or high-speed stability.

These are hypotheses, not a single-cause verdict. The Unity gray-box baseline must replay current step, release, reversal, slalom, and wall-glance cases with telemetry before tuning. Do not copy “0.82” or “0.92 per tick” into C# as sacred constants.

### 6.2 One normalized intent path for every device

Use Unity Input System action maps `Race`, `UI`, and `Debug` (debug excluded from release). At each fixed tick, device input follows one observable pipeline:

`raw sample -> device calibration -> inner/outer deadzone -> monotonic response curve -> speed-sensitive authority -> critically damped filter / asymmetric slew -> quantize -> InputIntent ring`

Telemetry records every stage plus speed, target/actual yaw rate, yaw acceleration, slip angle, lateral acceleration, track deviation, wall contact impulse, touch IDs, control scheme, thermal/frame state, and tick. Filter state resets safely on pause, background/foreground, controller loss, respawn, scene load, and input-lock transitions; no stuck finger/button survives an iOS interruption.

Initial candidates—not acceptance constants—are gamepad inner deadzone 0.12, outer 0.98, exponent around 1.6; a touch radius scaled by physical/safe-area dimensions; 180–260 ms steer rise and 120–180 ms return; and materially lower authority at terminal speed than the present 82%. The controller should target a speed-dependent yaw rate with soft saturation and a damped error term. Lateral tire/hover grip must be expressed in seconds/delta-time-independent decay, not a fixed 92% deletion per tick. Keep airbrake, sideshift, drift, and accessibility assists as distinct layers so they do not secretly alter the base response curve.

### 6.3 Touch and gamepad design

**Touch, landscape:** left side is a floating steer zone or bounded horizontal scrub with a visible neutral/lock indication; auto-thrust is the onboarding default. The right cluster exposes boost, fire/hold-to-absorb, utility, and brake; edge paddles provide airbrakes and deliberate swipe/double-tap provides sideshift. Respect iPhone/iPad safe areas and hand reach, offer left-handed mirroring and control scale/opacity, and prevent camera/system gestures from stealing an active race touch. Tilt steering is an optional later experiment, never the default. Haptics are semantic and rate-limited; reduced haptics/flashes/motion are independent settings.

**Gamepad:** support extended gamepads through Input System, analog steer and triggers, remapping, glyph changes, reconnect, multiple-controller ownership, pause/menu navigation, and controller battery/disconnect interruption. Test at least one current PlayStation-class and one Xbox-class MFi-compatible controller physically. Keyboard remains an Editor/debug and legacy comparison path, not an App Store interaction assumption.

### 6.4 Objective and piloted acceptance

Pure/controller gates for fixed-speed step tests begin with:

- left/right mirrored peak yaw and steady radius within 2%; no sign inversion;
- 10–90% filtered steer rise 180–260 ms, center return 120–180 ms, full reversal 300–420 ms;
- yaw-rate overshoot below 10%, no sustained oscillation, no hard-cap chatter;
- identical quantized intent/state hash for repeated same-build replay;
- high-speed small-input gain lower than low-speed gain, continuous with no curve kink;
- background/pause/controller-loss clears all pressed state in one controlled transition.

Pilot gate: at least five blind pilots run matched seeds on Neon and Foundry; touch and gamepad each have adequate coverage rather than combining all observations. Compare legacy-feel baseline, candidate A, and candidate B without labels. Ship when median smoothness and control-confidence are at least 4.5/5, no pilot rates either below 4, at least 80% prefer the winner, wall contacts/km improve at least 30% from the native untuned baseline, and median clean-lap time worsens no more than 3%. The captain separately signs off “buttery.” Attach screen recording, build/device/track/ship/seed, input+vehicle telemetry JSON/plots, questionnaire, and analysis—not a prose assertion.

## 7. SpacetimeDB multiplayer on Unity

The current server is `module/` TypeScript using the npm `spacetimedb` 2.6.x package. Keep it running during native parity. Pin a mutually compatible SpacetimeDB CLI, server, and Unity SDK in the repo; do not assume the npm package number equals the CLI release number. The vendor explicitly warns that generated bindings fail when CLI and SDK versions do not match. Add the official C# Unity package from `https://github.com/clockworklabs/com.clockworklabs.spacetimedbsdk.git`, generate C# module bindings into the networking assembly, and commit the generator version and schema hash. [SpacetimeDB Unity tutorial](https://spacetimedb.com/docs/tutorials/unity/), [C# SDK setup](https://spacetimedb.com/docs/clients/c-sharp/).

The C# SDK requires the client to call `FrameTick()` to apply incoming messages. A presentation-rate `SpacetimeConnectionBehaviour` advances the SDK on the main thread and converts callbacks into immutable, tick-stamped inbox records. The simulation drains those records only at its fixed-tick boundary. Network callbacks never mutate simulation stores, transforms, UI, or physics directly. Vendor docs also note reconnection is inconsistent across SDKs, so implement an explicit background/foreground, reachability, token-expiry, backoff, resubscribe, and state-resync machine. [Connection lifecycle](https://spacetimedb.com/docs/clients/connection/).

Recreate the current local/online `MatchAdapter` boundary in C#:

- `LocalMatchAdapter` performs no connection and owns solo phase/clock.
- `SpacetimeMatchAdapter` is online phase/clock and authorized reducer boundary.
- Store tokens in iOS Keychain, not PlayerPrefs. Anonymous identity may match the present behavior for the first slice; Sign in with Apple/account recovery is an explicit product decision before public release.
- Subscribe only to match-scoped rows; avoid the current broad client pattern as schema work proceeds. Check `compilerVersion`, track ID/version, gameplay hash, balance/schema version, app build, and server compatibility before grid entry.
- Preserve server-token respawn, monotonic checkpoints, idempotency, movement/time validation, combat authority/fairness, and no global mutation from client callbacks.

Acceptance includes local MainCloud/integration database runs, two real devices, background for 30 s/5 min, airplane/network switch, duplicate/out-of-order/reducer failure, expired and wrong-server tokens, reconnect during countdown/race/results, burst traffic, 100–250 ms shaped latency, binding regeneration, and IL2CPP/linker/AOT build. A later server rewrite to C# is a separate post-parity ADR/PR only if operations or measured performance justify it.

## 8. Stability, frame consistency, and release evidence

### 8.1 Physics and fall-through

Art never owns gameplay collision. The C# track artifact builds a continuous, closed, solid track collider/slab and recovery surfaces independently of generated skins. Racer bodies use an explicitly tested collision-detection mode, interpolation, layer matrix, hover raycasts, and safe respawn poses. Generated mesh colliders are reserved for non-drivable prop collision only where simplified proxies are insufficient; visual topology changes cannot silently change the racing floor.

Gates:

- PR: both tracks, every collider chunk/seam, all eight start poses, boost/coast, maximum speed, reverse/side impacts, crest/descent/bank, simulated frame stalls, background/resume, and recovery. At least 10 seeds × 3 laps in headless/play/device mix, zero fall-through.
- Nightly/release: both tracks × all ships with 10 seeds × 20 laps plus targeted seam stress and injected 1–5 skipped-render-frame patterns, zero fall-through or invalid recovery. Record minimum signed distance to surface, contact loss duration, position/velocity at recovery, and failure capture.
- Long race soak: no collider tunneling, body NaN/Inf, sleeping racer, explosive correction, or respawn loop. A raycast suspension is ride feel; the solid floor remains the safety authority, preserving the lesson in the current real-Rapier regression.

### 8.2 Crash/memory/lifecycle soaks

Affected PRs get a 30-minute physical-device loop on the oldest supported phone and tablet. Release candidate gets at least two hours per track/device tier with all ship/weapon/VFX families cycled. Inject app background/foreground, lock/unlock, Control Center, audio route change, controller disconnect, low-memory warning where testable, network loss, scene reload, and repeated race/menu loops.

Pass = zero uncaught exception, native crash, watchdog termination, hang, jetsam, pink/missing shader, leaked connection, unbounded managed/native/GPU memory, lost audio, stuck input, or corrupt save. Capture Xcode device logs, Organizer/Diagnostics symbols, Unity profiler memory snapshots at start/mid/end, thermal state, battery state, scene transitions, and exact build/device/OS.

### 8.3 Frame-time series, not averages

An in-game ring buffer and export records every frame: CPU main/render, GPU time where available, fixed-tick cost/backlog, render scale, quality tier, draw calls, batches, visible triangles, texture/mesh memory, GC allocation/collections, shader compilation/warmup, streaming requests/missing mips, overdraw proxy, thermal state, target/actual refresh, and scene/sector/event markers. Correlate it with Metal HUD/Instruments and Unity Profiler captures.

Report warm and hot windows separately, with p50/p95/p99/max, 1% and 0.1% lows, frames over 16.67/33.3 ms (and 8.33/16.67 in 120 mode), longest consecutive miss, hitch causes, memory slope, and thermal transitions. Quality tuning responds to sustained data at menu/lap boundaries; no per-frame feedback loop thrashes render scale or refresh. Apple explicitly recommends testing ProMotion changes and thermal behavior on actual devices, not assuming the requested refresh.

## 9. REQUIRED TOOLS inventory

### 9.1 Current laboratory state

The current Mac has Homebrew and 1Password CLI but has **none** of the native production chain installed: no Unity Hub/Editor, no iOS Build Support, no Xcode.app or `simctl`, no XcodeBuildMCP, no Git LFS, no SpacetimeDB CLI, and no fastlane. `xcodebuild` reports that the active developer directory is Command Line Tools. Therefore milestone N0 is a real procurement/setup gate, not housekeeping that can be assumed complete.

Costs below are verified or labelled variable as of 2026-07-13. Crew-installable means crew can perform installation after the captain has supplied any account, license, machine, role, or secret. Secrets live in the approved secret manager/GitHub environment, never Git/LFS/build artifacts.

| Required item | What it is / why required | License or cost | Provider | Setup and proof |
|---|---|---|---|---|
| Apple-silicon development Mac | Runs Unity Editor, Xcode, local signing, Instruments, and emergency release builds. Recommend 32 GB RAM and ample SSD for Library/DerivedData/raw assets. | Hardware/operations cost varies. | **CAPTAIN supplies/authorizes hardware.** Crew configures. | Confirm macOS compatible with pinned Xcode, disk encryption, updates policy, free disk, runner isolation, and a signed sample device build. Current lab Mac exists but lacks native tools. |
| Dedicated self-hosted Apple-silicon CI Mac | Required for deterministic Unity iOS generation, `xcodebuild archive`, codesign, and physical-device/simulator jobs; GitHub-hosted macOS may supplement but should not own secrets/device matrix. | Hardware + electricity; GitHub self-hosted runner software free. | **CAPTAIN.** | Enroll as locked-down runner, separate non-admin account/keychain, no personal iCloud, ephemeral workspaces, protected environment, concurrency=1 for signed archives. |
| Unity Hub | Installs/pins Unity and modules. | Free application; Unity account required. | Crew installs; **captain supplies Unity Organization/account access.** | Install current stable Hub (record version in setup ADR), sign in, install exact editor and module, verify CLI/batchmode. Do not let Hub auto-open/upgrade the project. |
| Unity 6.3 LTS `6000.3.19f1` ARM64 | Exact project Editor; LTS supported through Dec 2027. | Unity Personal free if total revenue+funding ≤$200k; Pro required above, currently $2,310/year/seat prepaid or $210/month; Enterprise required above $25m, custom. [Unity pricing](https://unity.com/products/pricing-updates). | **CAPTAIN attests financial tier and assigns required seats.** Crew installs. | Install exact hash via Hub; commit `ProjectVersion.txt`; CI asserts version. Run Metal/importer risk spike before production lock. |
| Unity iOS Build Support module | Emits the Xcode iOS project from Unity. It is not Xcode itself. | Included with licensed Editor. | Crew installs once Unity seat exists. | Add the matching 6000.3.19f1 iOS module in Hub; batchmode-generate Xcode project and archive it. Unity's release page lists the exact module. |
| Unity packages: URP, Input System, Test Framework, Unity.Mathematics, optional Addressables | Shipping renderer/input/tests/data math and, if proven needed, content streaming. | Included Unity packages under Unity terms; no separate fee. | Crew. | Pin exact versions in `Packages/manifest.json`/lock; create URP assets per tier; enable new Input System; run Edit/Play tests. Add Addressables only when sector/content measurements justify it. |
| Xcode 26.6 stable | Compiles/signs iOS/iPadOS, simulators, Instruments/Metal tools, Organizer archives/crash symbols. Apple requires App Store uploads to use Xcode 26+ since 28 Apr 2026; 26.6 requires macOS Tahoe 26.2+. [Current Xcode matrix](https://developer.apple.com/support/xcode), [upload requirement](https://developer.apple.com/news/upcoming-requirements/). | Free from Mac App Store/developer downloads. | Crew installs; **captain grants Apple account if archived downloads are needed.** | Install Xcode.app, accept license, install iOS runtimes, `xcode-select` it, run first-launch components, prove `xcodebuild -version`, `simctl`, simulator and physical build. Current state is CLT-only. |
| Apple Developer Program organization | Required for durable device signing, TestFlight, App Store distribution, App Store Connect/API. | $99 USD/year or local equivalent; legal enrollment/D-U-N-S may be required. [Apple membership](https://developer.apple.com/support/compare-memberships/). | **CAPTAIN ONLY: enrolls/renews legal entity.** | Create/confirm Team, agreements/tax/banking as applicable, Account Holder, and least-privilege App Manager/Developer roles. Record renewal owner/date. |
| Bundle ID, App Store Connect app, signing identities/profiles | Product identity and trust chain for development, Ad Hoc if used, TestFlight/App Store distribution. | Included in Developer Program; operational secret handling. | **CAPTAIN creates/approves app identity and grants roles; captain/authorized release owner creates distribution credentials.** | Fix reverse-DNS bundle ID, capabilities, automatic-vs-managed signing ADR. Put certificate/key in CI keychain and provisioning profile/API `.p8` in protected secrets; document rotation/revocation. Never commit. |
| App Store Connect API key | Non-interactive TestFlight upload/status and metadata automation. | Included with program. | **CAPTAIN/Account Holder or authorized Admin only.** | Create least-privilege key, store issuer/key IDs and `.p8` as protected secrets, restrict release workflow/environment, test upload, document rotation. |
| Real device matrix | Only valid proof for Metal GPU, texture residency, thermals, ProMotion, haptics, memory/jetsam, touch reach, controller latency. | Hardware varies. | **CAPTAIN procures/assigns.** | At minimum: oldest supported iPhone, oldest supported iPad, median 60 Hz iPhone/iPad, ProMotion iPhone/iPad, current and oldest supported OS where feasible; asset tags and charged/thermal-controlled procedure. Final models wait on support-floor decision. |
| iOS/iPadOS simulators | Fast build, lifecycle, UI, accessibility, screenshot, smoke coverage; not performance proof. | Included with Xcode. | Crew. | Install runtimes matching support floor/current OS; create named phone/tablet devices; use deterministic language/orientation/content size. Mark all simulator performance output non-acceptance. |
| Physical game controllers | Validates Input System mappings, glyphs, disconnect/reconnect and feel. | Hardware varies. | **CAPTAIN procures/assigns at least one PlayStation-class and one Xbox-class compatible controller.** | Pair with phone/tablet; record firmware/model; include in pilot and interruption matrix. |
| `com.unity.cloud.gltfast` | Apache-2.0 Unity package for GLB/glTF Editor import into native prefabs; primary Tripo import path. | Free/open source, Apache 2.0. | Crew. | Pin package, import sample raw GLB, include shader variants, convert to canonical URP material, validate in IL2CPP/Metal build. |
| Blender LTS/current pinned version | Optional source inspection, uniform transform/pivot/UV/normal/LOD cleanup when regeneration is not needed; FBX only as temporary interchange. | Free/open source GPL; artwork output is not made GPL by tool use. [Blender licensing](https://docs.blender.org/manual/en/latest/getting_started/about/license.html). | Crew. | Pin version and export preset; apply transforms and preserve source; script reproducible inspections where worthwhile. Do not make `.blend` or FBX an unexplained source of truth. |
| Unity texture importer + ASTC encoder | Produces shipping Metal texture variants, mipmaps and streaming budgets. | Included with Unity. | Crew. | Define import presets by channel/category/tier; golden material balls; verify ASTC dimensions/formats/memory on device. |
| Khronos KTX-Software (`ktx`) | Optional source KTX2 validation/conversion and forensic comparison; not the Unity runtime texture loader. | Free/open source; repository-unique files generally Apache 2.0, bundled components carry their own compatible notices and one documented exception. Review the shipped SPDX/BOM. [KTX-Software license](https://github.com/KhronosGroup/KTX-Software/blob/main/LICENSE.md). | Crew installs if source uses KTX2. | Pin release, run `ktx validate/info` in asset checks, retain required notices, keep Unity ASTC as runtime output. |
| Tripo API account/credits/key + web access | Generates every visible 3D asset; API primary, web fallback. | Existing balance approximately 24,170 credits; future top-ups variable under Tripo terms. | **CAPTAIN supplies account, billing approval, web access, and 1Password key; already present in this lab.** Crew operates within ledger. | Read secret at runtime, never print; API health/one low-cost proof only in implementation; set 20,500 cap/3,670 reserve; reconcile task IDs and balance. |
| Git LFS client and GitHub LFS budget | Tracks immutable raw GLBs, textures, videos, and other large binaries without bloating Git objects. Current client is missing. | Client free/open source. GitHub currently includes 10 GiB storage+bandwidth for Free/Pro and 250 GiB for Team/Enterprise; overage metered/blocked by budget. [GitHub LFS billing](https://docs.github.com/en/billing/concepts/product-billing/git-lfs). | Crew installs/configures; **captain approves repo plan and spending cap.** | `brew install git-lfs`, `git lfs install`; track raw GLB/textures/captures by explicit patterns; commit `.gitattributes`; CI runs `git lfs fsck` and rejects LFS pointers in `Assets` without content. Set 90/100% alerts. |
| Unity Git serialization strategy | Keeps scenes/prefabs/settings reviewable and mergeable. | Included. | Crew. | Force Text, Visible Meta Files; commit all `.meta`; ignore `Library/`, `Temp/`, `Logs/`, `Obj/`, `Build/`, `UserSettings/`; one owner for central scenes/URP assets; prefer prefabs/additive scenes; YAML merge tool only after tested. |
| SpacetimeDB CLI/server + MainCloud | Generates bindings, publishes/tests modules, and runs local integration database; MainCloud hosts production. Current CLI is missing. | SpacetimeDB repository is BSL 1.1 with a limited production additional-use grant and later AGPLv3+linking-exception conversion; commercial license may be required outside its terms. MainCloud has a free tier and metered energy-based pricing; actual plan/usage must be checked. [SpacetimeDB license](https://github.com/clockworklabs/SpacetimeDB/blob/master/LICENSE.txt), [MainCloud](https://spacetimedb.com/maincloud). | Crew installs/pins; **captain/legal confirms production license fit and supplies MainCloud org/database roles and budget.** | Determine the exact CLI/server compatible with the repo's npm `spacetimedb` 2.6.0 and pinned Unity SDK—do not infer version equality—then generate C#, record schema/version, and run local/staging. Do not silently use “latest.” |
| SpacetimeDB Unity C# SDK | Official Unity client package and generated typed tables/reducers. | Free/open source Apache 2.0 for the separate Unity package; MainCloud/server terms and usage remain separate. [Unity SDK license](https://github.com/clockworklabs/com.clockworklabs.spacetimedbsdk/blob/master/LICENSE.txt). | Crew. | Pin Git commit/tag in Package Manager, retain notices, run `FrameTick`, IL2CPP/linker test, main-thread inbox, Keychain token wrapper, reconnect suite. |
| GameCI Unity Builder/Test Runner v5 + GitHub Actions | Reproducible batchmode tests and Unity build orchestration. Use Linux/cheap jobs for pure EditMode where supported; dedicated Mac for iOS/signing/device. | GameCI open source/MIT; GitHub Actions plan/runner costs vary. | Crew configures; **captain supplies GitHub admin, runner, Unity license secret, and Actions budget.** | Pin action SHAs, protect workflows/environments, cache Library safely by version/manifest, run Unity tests, generate Xcode, hand to signed Mac job. [GameCI Unity Builder](https://github.com/game-ci/unity-builder), [GameCI iOS deployment](https://game.ci/docs/github/deployment/ios/). |
| fastlane (Bundler-pinned) | Automates archive/export/upload/TestFlight and signing metadata without replacing Xcode. | Free/open source MIT. [fastlane](https://github.com/fastlane/fastlane). | Crew. | Commit `Gemfile.lock`, opt out of usage metrics if required, define build/upload lanes, use App Store Connect API key, never run signing mutations on untrusted PRs. |
| Unity Build Automation | Evaluated managed alternative, not primary CI. | Unity plan includes a limited current free allowance (Unity reports 100 Mac minutes/month in 2026), then metered. | **Captain would link Unity Cloud/billing.** | Do not set up initially. Reconsider only if self-hosted runner reliability/ops cost is worse; run a cost/reproducibility spike first. |
| TestFlight/App Store Connect | Internal/external beta and release distribution. TestFlight supports up to 100 internal and 10,000 external testers; first external build needs beta review. | Included with Apple membership. [TestFlight limits](https://developer.apple.com/testflight/). | **Captain provides app, agreements, tester groups, release roles.** Crew uploads after gates. | Create internal/BRB/external cohorts, beta metadata/contact, export compliance, review notes; manual protected dispatch after checks-passed + BRB YES. |
| Unity Diagnostics + Apple Organizer/MetricKit | Crash/error reporting, symbols, device diagnostics and production performance/crash confirmation. Unity 6.2+ Diagnostics is built into new projects; legacy Cloud Diagnostics is deprecated. | Diagnostics is part of Unity's Developer Data/Cloud surface; no separate price was published in the cited setup page, so plan limits/terms must be confirmed. Apple tools are included. [Current Unity Diagnostics](https://docs.unity.com/en-us/cloud/developer-data/diagnostics). | Crew integrates; **captain approves Unity Cloud link, data processing/privacy, and any billing.** | Link dev/staging/prod environments, enable approved collection, symbol upload, deliberate crash proof in nonproduction, retention/access policy, App Privacy disclosure. Keep Apple Organizer as independent source. |
| Unity Analytics (minimal) | Build/device/tier, race completion, quality and control opt-in telemetry; not a substitute for local frame series. | Current free tier to 50k MAU, then usage pricing. [Unity Analytics pricing](https://docs.unity.com/en-us/analytics/pricing-and-billing/mau-based-pricing). | Crew implements only approved events; **captain approves privacy/consent and spend.** | Data dictionary, consent/opt-out and deletion path, dev/prod separation, event cap, privacy manifest/disclosure. Do not send raw input traces from public users without explicit policy. |
| XcodeBuildMCP | Agent-accessible Xcode project/scheme/simulator/build/test/log/screenshot operations; complements, not replaces, `xcodebuild`. | Free/open source MIT; optional error telemetry should be disabled if policy requires. [XcodeBuildMCP](https://github.com/getsentry/XcodeBuildMCP). | Crew installs/configures. | Install pinned release, set `XCODEBUILDMCP_SENTRY_DISABLED=true` if required, register MCP, run doctor/list/build/test/screenshot. Current lab lacks it. |
| `bootstrap-ios` agent skill | Routes agents to XcodeBuildMCP, CLI, Simulator, and Apple-specific workflow conventions. | Already installed user-level; no project license cost. | Crew/tooling environment. | Keep skill available to Apple lanes; agents must still use repo commands and evidence gates. It does not supply Xcode, signing, or devices. |
| `no-mistakes` and `running-bug-review-board` skills/services | Required landing review/check and real-user QA/decision evidence. | Existing internal tooling; operational cost external to repo. | Existing firstmate/captain environment; crew configures project commands. | Add Unity commands/artifacts, never restart shared no-mistakes daemon, keep BRB auto-QA separate, require YES/no P0/P1. |
| Metal HUD, Instruments, Unity Profiler/Frame Debugger | Shipping-backend CPU/GPU/frame/memory/thermal evidence. | Included with Xcode/Unity tier. | Crew. | Capture named physical-device templates and CSV/traces; archive exact build; strip profiler connection from release. |
| Node/pnpm and current web dependencies | Maintain legacy oracle and TypeScript SpacetimeDB module during migration. | Existing open-source dependencies and hosting costs. | Crew; captain owns hosting/account. | Keep pinned lock, `pnpm test/build/track:check`, security-only web maintenance, and module workflow until retirement. |

### 9.2 Distinct captain-only/provision checklist

Nothing below can be safely fabricated or self-approved by crew. Native work can begin locally in limited form, but signed device/CI/TestFlight/release gates remain blocked until the applicable boxes are supplied.

- [ ] Attest total Unity revenue+funding tier; create/confirm Unity Organization and assign Personal/Pro/Enterprise seats compliant with that tier.
- [ ] Approve exact Unity 6.3 LTS patch policy and accept the Unity terms on the organization account.
- [ ] Enroll/renew the legal entity in the Apple Developer Program ($99/year), maintain Account Holder access, D-U-N-S/legal agreements, and renewal owner.
- [ ] Choose final bundle ID/product name/team and create the App Store Connect app; grant least-privilege App Manager/Developer access.
- [ ] Provide or authorize development/distribution signing certificates, provisioning, protected CI keychain, and App Store Connect API key; own rotation/revocation.
- [ ] Decide minimum iOS/iPadOS version and minimum device promise. This determines the actual oldest acceptance devices and store compatibility.
- [ ] Procure/assign the physical matrix: oldest supported iPhone+iPad, median 60 Hz phone+tablet, ProMotion phone+tablet, plus compatible PlayStation- and Xbox-class controllers.
- [ ] Provide/authorize a dedicated Apple-silicon self-hosted CI Mac, secure runner account, power/network/maintenance owner, and GitHub protected-environment administration.
- [ ] Approve GitHub plan/LFS storage and bandwidth budget, including raw Tripo/video growth alerts and overage stop.
- [ ] Provide SpacetimeDB MainCloud organization/database/staging roles and approve usage budget; decide public authentication direction before beta.
- [ ] Maintain Tripo account/web access/API secret/top-up authority and approve the 20,500-credit ceiling/protected reserve.
- [ ] Approve Unity Cloud Diagnostics/Analytics linkage, data-processing/privacy/consent policy, production access, retention, and any usage spend—or direct crew to Apple-only crash metrics and no gameplay analytics.
- [ ] Create/approve TestFlight internal/external groups, beta contact/review information, App Store agreements/tax/export-compliance/privacy/age-rating metadata, and final release authority.
- [ ] Decide whether the public web demo receives a migration banner and the exact retirement date after native v1; authorize endpoint shutdown when the gate is reached.

## 10. Unity-aware CI, no-mistakes, and BRB

### 10.1 CI topology

Use **GameCI/GitHub Actions plus a dedicated self-hosted Mac** as the primary path. Pure C# analyzers, format, manifest/provenance checks, legacy TS tests, and eligible Unity EditMode tests can run on cheaper trusted jobs. The Mac lane opens the exact Unity version in batchmode, runs EditMode/PlayMode, generates the iOS Xcode project, builds simulator and IL2CPP device configurations, archives/signs only on protected branches/environments, and uploads symbols/evidence. fastlane performs protected TestFlight upload after human dispatch.

CI stages:

1. Repository hygiene: LFS objects present, `.meta` completeness, Force Text expectations, no secrets/large raw Git blobs, package/version locks, deterministic generated-file diff.
2. Static: C# analyzers/format, forbidden assembly dependencies, visible-renderer provenance graph, primitive-fallback and debug-hook release audit, texture/mesh/import budgets.
3. Tests: pure C# EditMode, cross-language fixtures while web oracle lives, track compiler goldens, PlayMode scene/controller/physics, legacy `pnpm test/build/track:check` for touched shared/module code.
4. Unity builds: simulator smoke and iOS IL2CPP Metal player; shader-variant and asset-catalog validation; development and release profiles distinct.
5. Signed protected job: `xcodebuild archive`/export, symbol map/dSYM, install/smoke on device pool where available, notarized evidence bundle.
6. no-mistakes review/check artifacts; BRB independent auto-QA decision; TestFlight manual dispatch only after both pass.

Pin action commits and tool versions; do not allow pull-request code from forks to access signing, Apple, Unity, Tripo, or Spacetime secrets. Cache keys include Unity editor, platform, package lock, and asset-import revision. A stale Library cache is disposable, never source truth.

### 10.2 Evidence artifact contract

Each PR stores a machine-readable manifest and human index under `docs/native/evidence/<milestone>/<build>/` or immutable CI artifact with a durable link. It includes commit/build, Unity/Xcode/package versions, device/OS/thermal/battery, scene/track/ship/seed, settings/tier/render scale/target refresh, test outputs, console/device logs, frame/input series, and screenshot/video hashes.

BRB applies the installed iOS playbook: XcodeBuildMCP or CLI proves project/scheme/build/test/simulator evidence; physical devices prove actual gameplay; simulator accessibility/UI captures do not masquerade as Metal performance. Findings are filed with repro, expected/actual, severity and evidence. Release proceeds only on explicit YES with no open P0/P1.

## 11. Fate of the web build

**Recommendation: staged freeze, then public retirement.**

At native kickoff, tag the exact web oracle and stop all new web art, renderer, gameplay, AI, multiplayer, and release features. Permit only critical security, dependency, uptime, and oracle-export fixes. Keep the current web app internally accessible for cross-language fixtures and historical visual evidence. If the existing public deployment remains reachable, add a clear “native version in development” banner without promising a date.

After native v1 is live in the App Store for 30 days with the release crash-free/retention gates met, retire the public web race app and its unused online endpoints. Preserve source tag, lockfile, build artifact, audit evidence, test fixtures, and a static landing page. This avoids permanently funding two renderers, input surfaces, physics adapters, QA matrices, and multiplayer clients—especially when the public web visuals are already rejected.

## 12. Reconciliation of the existing roadmap

The native transformation is not a new P5 coat of paint after the old roadmap. It reopens the feel gate, ports the trustworthy design in dependency order, and replaces browser production/release work.

| Existing item | Native fate | Ordering/exit change |
|---|---|---|
| G0 / smooth gate and N0 fixes | **Reopen and fold into N0/C1/C2/NET.** Current captain feedback proves steering is not accepted. Preserve local-vs-online authority and server-token/checkpoint containment as design. | Native gray-box control, physics, lifecycle and telemetry sign-off precedes bulk art and network schema freeze. |
| P1 fixed tick, track compiler, CraftController, time trial | **Port semantics; do not mark done in native until C# parity/device gates.** | Oracle export -> pure sim -> compiler -> Unity Physics/controller -> touch/gamepad -> both tracks. The 5-pilot feel gate rises to the criteria in section 6. |
| P2 energy, pickups, weapons/utilities, VFX | **Port pure rules; replace every presentation asset.** | Rules can port in parallel after sim contracts. Visible pickups/pads/projectiles/VFX move into generated-asset milestones; primitive presentation dies. |
| P3 AI and second track | **Port before P4 schema freeze.** AI personalities/design carry; live adapters and visuals rebuild. | Both Neon and Foundry, eight-craft physics, items/combat and fairness must pass C# seeded/device gates. The current `Scene.tsx` AI-only-Neon condition cannot carry. |
| P4 multiplayer PF/M0/M1–M8 | **Re-express against C# client and existing TS server.** | PF = schema/hash/auth/release prerequisites. M0 = both-track native AI/combat parity. M1–M8 then add match lifecycle, scoped subscriptions, authoritative checkpoints/respawn/combat/results/reconnect. Avoid simultaneous server rewrite. Defer nonessential ghost collision/network spectacle if it threatens v1. |
| P5 art slice marked complete | **Rejected and replaced wholesale by A0–A7/R1.** | Eight near/mid web GLBs plus seven sparse props do not satisfy coverage. The forensic violation inventory is the new zero baseline. |
| P6 browser production/release | **Dies as a shipping target; replaced by iOS production.** | Unity CI, IL2CPP/Metal, physical matrix, privacy/accessibility, TestFlight, App Store, symbols/diagnostics, thermal/memory/release soak. |
| Desktop-only controls; touch later | **Dies.** | Touch and gamepad are first-class before art scale-up. Keyboard is debug only. |
| CC0-first/procedural environment strategy | **Dies.** | Tripo-generated coverage is binding; third-party HDRI may light the scene but cannot replace generated visible world assets. |
| 25 MB browser payload and web DPR budget | **Dies.** | Replace with install/download size, texture/mesh residency, streaming, memory, thermals, and App Store constraints per device tier. |
| No full-screen motion blur / reduced motion and flashes | **Keep.** | Use object/mesh motion cues, independent reduced-motion/reduced-flash controls, and device-tested accessibility. |
| Same-build local determinism | **Keep, scoped honestly.** | C# pure rules/replays are deterministic within pinned build; Unity Physics is not promised bit-identical across devices/OS/editor patches. Online server authority remains necessary. |

Reordered critical path:

`tools/accounts/oracle -> C# sim/compiler -> Unity Physics + buttery controls -> URP/asset vertical slice -> total generated coverage -> AI both tracks -> C# online client/server hardening -> streaming/stability -> TestFlight/App Store`

## 13. Single-PR milestones and parallel execution

### 13.1 File ownership lanes

After the foundation PRs, parallel work is mandatory but should be achieved through narrow ownership, not simultaneous scene editing:

| Lane | Exclusive/default paths | Can proceed alongside | Integration rule |
|---|---|---|---|
| Tooling/release | `.github/`, `unity/KZero/Assets/KZero/Editor/Build/`, `docs/native/release/` | All lanes after N0 | Only release owner changes signing/build profiles. No PR secrets. |
| Simulation/rules | `Runtime/Simulation/`, pure rule tests/fixtures | Render, assets, toolchain, network shell | Does not touch scenes/URP/physics adapter. Schema changes require short ADR and fixture revision. |
| Track/compiler | `Editor/TrackCompiler/`, runtime artifact reader, `Art/Track/<one-track>/` | Sim, ships/items, controls | Compiler owner alone regenerates artifacts. Track art uses `artVersion`; gameplay changes deliberately change hash/version. |
| Physics/controls | `Runtime/Physics/`, `Runtime/Input/`, device control tests | Render/asset tooling, pure rules | One controller tuning owner at a time. Presentation reads snapshots only. |
| Render/camera | `Presentation/Render/`, `Presentation/Camera/`, URP assets | Asset batches, rules, network | One owner for shared URP assets/lighting profiles; tracks own additive lighting instances, not pipeline assets. |
| Asset pipeline/art | `Editor/AssetPipeline/`, `SourceAssets/Tripo/<assigned category>`, `Art/<assigned category>` | All code lanes, other disjoint categories | Each batch owns unique asset IDs/manifests. A0 validator precedes bulk merges. |
| AI | `Simulation/AI/`, AI tests/fixtures | Render/assets/network shell | Emits common intent only; no physics/render cheats. |
| Network/server | `Runtime/Networking/Spacetime/`, `module/` | Render/art/controls after interfaces stable | One schema owner. Generated bindings never hand-edited; server reducer changes separate from client cosmetics. |
| QA/evidence | `Tests/Device/`, `docs/native/evidence/` and test plans | All | QA does not change feature code in evidence PR; files bugs or returns gate result. |

Central bootstrap scene, package manifest, project settings, quality/URP assets, track artifact registry, item/ship catalog, and App Store configuration are integration-owner files. A parallel PR that needs one adds a small request/manifest entry rather than casually merging the scene. Prefer additive scenes and prefabs so Neon, Foundry, ships, and VFX asset batches remain disjoint.

### 13.2 Milestone graph

Every row is one landing PR. “Evidence” below is additional to the universal gate in section 2.3.

| ID | Single-PR scope and planned paths | Depends | Evidence-backed acceptance |
|---|---|---|---|
| N0 | Tool/account bootstrap ADR, exact version manifest, Unity/LFS ignore strategy, captain-blocker checklist; no gameplay. `docs/native/setup`, `.gitattributes`, `.gitignore` | Captain supplies minimum accounts/hardware | Tool probe records exact Unity/Xcode; signed empty iOS app installs on one phone+iPad; simulator smoke; LFS round-trip; no secret in repo. |
| N1 | Minimal `unity/KZero` URP project, assembly definitions, package locks, quality-profile placeholders, boot/menu scene | N0 | Batchmode opens with 6000.3.19f1, no reserialize diff; Metal/IL2CPP build; assembly dependency test; blank scene holds 60/120 pacing without gameplay claims. |
| N2 | GitHub/GameCI + self-hosted Mac Unity checks, iOS generation/archive dry run, evidence manifest | N1 | Clean clone runs static/Edit/Play/iOS build; unsigned PR job has no signing access; protected test archive succeeds; cache cold/warm results; no-mistakes recognizes artifacts. |
| O1 | Freeze/tag web oracle and export canonical JSON fixtures/goldens/tuning/track artifacts/screenshots | N0 | Legacy `pnpm test/build/track:check` pass; fixtures include reset/gate/input/race/energy/items/combat/AI cases with hashes and documented intentional gaps. No source behavior change. |
| S1 | C# integer tick, ordered runtime, seeded RNG, quantized input ring, snapshots/events in `Runtime/Simulation/Core` | N1, O1 | Tick-by-tick fixture parity for core cases; same-build 10k repeat hash; no UnityEngine Object/MonoBehaviour dependency; catch-up metrics/limits tested. |
| S2 | Race, energy, inventory/pickup rules and persistence DTOs, no UI | S1, O1 | Cross-language fixtures match or approved versioned deltas; death/respawn boundary ticks and roll-table sums; pause/reset/gate tests. |
| S3 | Combat/weapon/utility/control-loss pure rules, no VFX | S1–S2 | Seeded combat replay, caps/immunity/no-one-shot/refund; event stream matches fixture; zero presentation references. |
| T1 | C# track schema/quantization/RMF compiler and runtime artifact reader | S1, O1 | Both track semantic artifact fields/hashes/golden frames; seam twist, bank, spawn/checkpoint/AI/respawn/recharge/pickup data; stale artifact check; intentional compiler-version policy. |
| P1 | Unity Physics world/track solid collider and hover-body adapter for one debug craft/sector | T1, S1 | Collision layer matrix, solid slab, suspension envelope, seams/crests/descents; targeted fall suite zero; no generated art dependency; frame series on oldest devices. |
| C1 | Input System action maps, touch/gamepad/keyboard-debug adapters, common shaping stages and telemetry; baseline tuning only | P1 | Safe-area phone/iPad layouts, controller reconnect/background clear, raw-to-intent plots, baseline step/slalom/wall data; all inputs feed same quantizer. |
| C2 | Speed-sensitive yaw/grip controller and candidate tuning; no final UI polish | C1 | Objective rise/reversal/symmetry/overshoot/no-chatter gates; both tracks gray-box; no fall regression; candidate A/B telemetry. |
| C3 | Pilot study and captain-selected tune/settings/onboarding copy as data-only landing | C2, T1 | ≥5 blind pilots, touch+gamepad/two tracks; median ≥4.5, none <4, ≥80% preference, wall contacts/km ≥30% better, lap penalty ≤3%; captain “buttery” sign-off and raw evidence. |
| R1 | URP/Metal foundation: linear HDR/ACES, IBL/probes, shadowed key, SSAO/bloom/grade, AA, frame/memory instrumentation, quality tiers | N1, P1 | Neutral/material reference renders and one gray sector on oldest/median/Pro devices; no missing shaders; 60 series meets headroom; 120 only labelled experimental if qualified. |
| A0 | Asset/provenance schema, glTFast import/canonical material tools, immutable-source/LFS convention, structural+visual diff and visible-renderer validator | N1, N2 | One sacrificial Tripo GLB goes source→prefab→IL2CPP; raw/import turntables; deliberate missing provenance, i8-like normal loss, nonuniform scale, missing shader and primitive fallback all fail CI. |
| A1 | Vertical slice: one raw 4k ship with three real LODs plus one fully generated Neon sector | R1, A0, C2 | Source/import/device eight-angle diffs, LOD fly-through, correct PBR/shadow/AO, no visible primitive in sector, steady 60 on min device and measured Quality/120 results. Captain visual go/no-go before bulk spend. |
| A2 | Remaining seven ship families + AI/ghost catalog/LODs | A1 | Eight racers together both lighting rigs; zero `farOnly`, box/card fallback, scale distortion, material/shader miss; per-asset manifest/diffs; device memory and transition series. |
| A3 | Pickups/drops and pads/boost/recharge/start-grid generated catalog | A0, T1, S2, A1 | Every socket resolves on both tracks; zero procedural crystal/plate/chevron; claim/respawn pooling; high-speed readability, z-fight and reduced-flash checks; provenance zero. |
| A4 | Generated weapon/utility/projectile/impact core meshes and URP VFX presentation | A0, S3, R1 | All catalog events render real mesh cores; freeze-frame provenance; bloom-off/reduced-flash readability; pool/overdraw/frame series under worst eight-racer combat. |
| A5 | Full Neon track skin, structures, props, vistas, lighting profile | A1, T1 | Camera-path renderer coverage zero violations; generated surfaces/rails/tunnels/skyline; fixed 1080p+ device capture deck; collision/gameplay hash unchanged for art-only update; min-tier 60 hot soak. |
| A6 | Full Foundry track skin, structures, props, tunnel, vistas, lighting profile | A1, T1 | Same gates as A5; specifically eliminates forensic floating box tunnel; distinct material/lighting identity; min-tier 60 hot soak. Runs parallel with A5 under disjoint path ownership. |
| A7 | Global sky/weather/star/rain generated mesh families, UI 3D renders, final provenance audit | A2–A6 | All scenes/catalogs report zero missing visible provenance; no visible points/primitives; weather overdraw tiers; menu icons trace to generated models; captain coverage sign-off. |
| AI1 | C# AI personalities/driver/overtake/director and seeded headless race sim, no live bodies | S1–S3, T1 | Rookie/Pro/Elite fixtures, no physics cheats, both-track 8-craft completion/collision/fairness thresholds, deterministic seed report. |
| AI2 | Live Unity AI bodies, shared controller/combat adapters, standings, full generated visuals | AI1, C3, A2–A4, A5/A6 | Eight racers both tracks, all tiers/items; same inputs/controller as player; no boxes; collision/standings/respawn; 60 worst pack/combat series and BRB race review. |
| PF | Native online prerequisite/schema ADR: IDs, versions/hashes, auth/token, subscriptions, compatibility and P4 scope | S3, T1, AI2 | C# and TS schema matrix; fail-closed mismatch cases; data migration/rollback plan; captain auth/min-OS decisions captured. No broad implementation. |
| NET1 | Pinned Spacetime C# SDK/bindings, Keychain token, main-thread `FrameTick` inbox, local/online adapter shell against unchanged server | PF, N2 | Local mode opens zero sockets; staging connect/subscription/reducer; binding regeneration clean; IL2CPP/linker; background/reconnect/wrong token; two devices. |
| NET2 | Online match lifecycle/clock/grid/checkpoint/respawn reducers and match-scoped subscriptions | NET1 | Two-device and fault matrix; server phase/clock authority, monotonic/idempotent checkpoints, one-time respawn token, compatibility rejection; no global `SELECT *`. |
| NET3 | Authoritative online items/combat/damage/death/results/reconnect and abuse limits | NET2, S3, AI2 | 2–8 clients/bots, latency/burst/duplicate/reconnect; fairness/caps/refunds/ownership; server logs and replay correlation; no client authority leak. Nonessential ghost collision can be deferred. |
| Q1 | Sector/content streaming, mip prefetch, instancing/SRP Batcher, shader warmup, memory/thermal tier tuning | A7, AI2, NET1 | Both tracks/all ships; no blurry spawn/cut, shader hitch or asset pop; p50/p95/p99/max series, memory slope and thermal; 60 headroom all min devices, earned 120 list. |
| Q2 | Full stability/fall/lifecycle/network soak automation and device BRB release candidate | Q1, NET3 | Defined 10×20-lap fall suites zero; ≥2 h/track/tier zero crash/hang/jetsam/leak; interruption matrix; accessibility/reduced-motion/flashes; BRB YES. |
| REL1 | TestFlight internal release automation, diagnostics/symbols, privacy/age/export metadata and tester plan | Q2 | Signed archive reproducible; dSYMs/symbolication proof; deliberate staging crash/nonfatal; TestFlight install on matrix; 100% required metadata; no production secret/log leak. |
| REL2 | External TestFlight findings closure and App Store submission candidate | REL1 | External cohort thresholds set in release ADR, no P0/P1, captain visual/feel/release sign-offs, release notes/support/privacy URLs/screenshots, rollback/live-ops plan, App Review package. |
| W1 | Public web retirement after native production gate | Native v1 live + 30 crash-free days | Static archive/landing preserved, online endpoints safely drained, monitoring/cost/security checklist, rollback window, captain authorization. Never precedes native evidence retention. |

### 13.3 Parallel waves

- **Wave 0:** N0/O1. Captain provisions while crew freezes the oracle.
- **Wave 1:** N1/N2 foundation; then S1. These are short critical-path PRs, not a mega-bootstrap.
- **Wave 2:** after S1, S2/S3, T1, R1, and A0 use disjoint paths; P1 begins as soon as T1 is ready.
- **Wave 3:** C1–C3 is sequential within its lane; A1 validates art/render. Bulk spend does not begin before both control and vertical-slice gates.
- **Wave 4:** A2, A3, A4, A5, A6, and AI1 run in parallel by category/track ownership. A7 integrates only after their manifests are green.
- **Wave 5:** AI2 and PF close native game/schema assumptions; NET1–NET3 is sequential because authority changes need a single schema owner. Q1 can begin against NET1.
- **Wave 6:** Q2, REL1, REL2, then W1 after the production waiting gate.

## 14. Decision gates, open questions, and risks

### 14.1 Decisions required from the captain

The provisioning checklist in section 9.2 is operational. These are product/architecture decisions that change acceptance:

1. **Minimum iOS/iPadOS and device floor.** Recommendation: choose the oldest tier only after A1 renders one ship/sector on candidate devices; support no device that cannot hold 60 hot. The App Store minimum OS should then be the oldest OS supported by that physical floor and Xcode/Unity packages.
2. **Business license tier.** Captain must attest Unity revenue+funding; crew cannot infer Personal vs Pro/Enterprise.
3. **Account identity.** Recommendation: retain anonymous Spacetime token for the internal slice, decide Sign in with Apple/account recovery before external TestFlight if progression/identity has value.
4. **Analytics/privacy.** Recommendation: Apple Organizer/MetricKit + Unity Diagnostics for crash quality; minimal consented Unity Analytics only for aggregate device/tier/race funnels. No public raw steering traces by default.
5. **Install/content size policy.** Recommendation: ship both tracks in v1 unless App Store/install-size or memory measurements require on-demand resources; do not add Addressables/remote catalogs until Q1 proves the need.
6. **Web banner/retirement.** Recommendation is freeze immediately, public retirement 30 crash-free production days after v1.

### 14.2 Risk register

| Risk | Likelihood/impact | Mitigation and tripwire |
|---|---|---|
| Unity 6000.3.19f1 known Metal timeout freeze/importer crash | Medium / critical | N1/A0 physical/import stress before lock; exact pin; capture repro. If hit twice, test the next 6.3 patch in isolated upgrade PR and compare all gates; do not silently drift. |
| Unity/Apple tool/license volatility | Medium / high | Pin versions, annually review costs/terms, preserve source formats and pure C# boundaries, keep release owner/renewal calendar. Unity choice remains captain direction. |
| Mobile thermals cannot sustain desired density/120 | High for 120, medium for 60 / high | 60-first tiers, A1 before bulk art, baked/static lighting, real LODs, streaming, overdraw caps, hot series. Drop optional 120 or effects—not 60 floor or generated coverage. |
| Generated art quality/topology inconsistency | High / high | Immutable source, constrained prompts, bounded attempts/credits, structural+visual diff, canonical materials, selective Blender cleanup/regeneration, captain A1 gate before scale. |
| Credit budget exhausted by retries | Medium / high | Per-category ceilings/attempt limits, 3,670 reserve, daily actual-balance reconciliation, reuse five raw 4k ships, stop at 3,500. |
| LFS storage/bandwidth explodes | Medium / medium-high | Source taxonomy, no duplicate intermediates, per-release video retention, LFS alerts/budget, immutable sources in LFS; captain approves plan before bulk generation. |
| PhysX behavior diverges from Rapier and replay | High / high | Port verbs/metrics, not impulses; pure fixed rules; cross-language fixtures; gray-box pilot/fall gates; honest same-build replay scope and server authority online. |
| C# track compiler changes artifact bytes/hash accidentally | Medium / high | Canonical semantic field comparison, explicit compiler version, checked-in goldens, separate gameplayHash/artVersion, never hand-edit artifacts. |
| Spacetime C# SDK/CLI mismatch or IL2CPP stripping | Medium / high | Pin exact SDK/CLI, generated binding check, AOT/linker device test in NET1, vendor-supported Unity baseline, no background-thread DB mutation. |
| Background/reconnect duplicates or loses authority events | Medium / critical | Tick-stamped inbox, idempotent reducers/checkpoints, explicit state machine/resync, fault matrix on two devices, server clock/phase authority. |
| Signing/CI becomes release bottleneck or secret risk | Medium / critical | N0/N2 first, dedicated Mac, least privilege/protected environment, API keys/certs rotated, unsigned PR jobs, local recovery build documented. |
| Scope explosion from “AAA” | High / high | Category inventory, A1 reference frame, fixed v1 tracks/ships/features, single-PR milestones, visual/60 gates. No feature advances while coverage violations remain. |
| Two live products split team/QA | High / high | Immediate web feature freeze and scheduled retirement; maintain oracle/security only. |
| Captain reference additions arrive midstream | Medium / medium | Store shot/scene/material reference matrix in `docs/native/art-direction`; apply at the next not-yet-approved asset batch. Reopening an approved family needs explicit impact/credit decision. |

## 15. Rejected alternatives

| Alternative | Why rejected | Reconsider only if |
|---|---|---|
| Re-litigate Three.js, Babylon.js, PlayCanvas, Unreal, or custom Metal instead of Unity | Superseded by binding captain direction. It would waste the migration window and does not address the immediate coverage/control failures. | Captain explicitly reverses the engine decision. |
| HDRP on iOS/iPadOS | Unity's Metal table supports HDRP on macOS only; it is not the mobile path. HDRP also conflicts with the required cross-tier mobile/120 strategy. | Unity officially supports and production-proves HDRP on iOS in the pinned generation, followed by an isolated device spike. |
| URP Deferred as default | Unity documents high mobile impact from G-buffer passes and no MSAA, while Forward is recommended for mobile. | A physical-device representative scene shows better total CPU/GPU/memory/quality across every supported tier. |
| Forward+ everywhere | Extra lights/probes do not automatically justify it and minimum devices need the simplest proven path. | R1/A1 series proves it wins without thermal/memory/regression cost; then enable only on qualifying tier. |
| Transpile TypeScript to C# or embed JS | Produces opaque/debug-hostile Unity code, preserves browser abstractions, complicates IL2CPP/AOT and does not validate semantic parity. | Never for shipping; one-off fixture generators may remain TS outside the app. |
| Port React/R3F/Three/Rapier wholesale via wrappers | Native presentation/physics/Input/lifecycle are the reason for the pivot; wrappers would keep rejected constraints and split ownership. | Never as product architecture; legacy stays oracle only. |
| Rewrite the SpacetimeDB server in C# simultaneously | Removes the stable oracle while client, physics, and renderer all change; magnifies schema/debug risk without demonstrated benefit. | Native client is parity-complete and operations/performance data supports a separate server ADR. |
| DOTS/ECS during port | Adds a second architecture migration and skill/tool surface. Current plain data runtime already has deterministic system boundaries. | Profiler shows a specific scale bottleneck that cannot be met with current data-oriented C# and a contained DOTS spike proves value. |
| Retain Rapier through a Unity native/plugin bridge | Adds platform/plugin/AOT maintenance and still requires adapters; current gameplay design is not cross-platform rigid-body deterministic. | Unity Physics cannot meet measured handling/fall gates and a maintained iOS Rapier integration proves lower total risk. |
| Visible primitive/procedural stand-ins, including “temporary” far LODs | Direct captain doctrine violation and the primary forensic failure. Temporary art tends to ship and invalidates visual/perf evidence. | Never for player-visible production paths; invisible colliders/gizmos only. |
| Blanket Unity mesh/vertex compression or meshopt force-recompress | The current pipeline's i8 normals/1k textures amplified faceting. Compression is asset- and attribute-sensitive. | Per-asset LOD visual diff/device proof passes with explicit settings; source and hero near stay lossless. |
| FBX as primary Tripo source | GLB preserves glTF PBR and provenance closer to provider output; FBX round trips commonly lose/reshape materials and adds an opaque conversion. | A specific DCC operation cannot preserve required data in GLB; retain raw GLB and record the deterministic FBX intermediary. |
| 4k textures everywhere | Wastes download, memory, streaming, bandwidth and thermals; the solution to destructive 1k blanket policy is selective fidelity, not blanket 4k. | A hero/near material diff and device memory series proves visible value on a named tier. |
| KTX2 runtime loader as the Unity default | Unity's native iOS importer/ASTC/streaming path is simpler and integrated; a parallel runtime loader adds shader/material/residency risk. | Remote/on-demand assets require it and a measured package spike passes IL2CPP/Metal/material/streaming gates. |
| TAA and full-screen motion blur by default | Fast chase cameras, transparent neon and LODs risk ghosting; motion blur harms readability and photosensitivity. | TAA passes scripted ghosting/clarity/60 gates on all tiers. Full-screen motion blur remains rejected; mesh/object cues suffice. |
| Unity Build Automation as primary from day one | Adds another billing/control plane and limited Mac minutes; signed-device/local recovery still needed. Dedicated GameCI Mac gives transparent build/signing control. | Self-hosted reliability/maintenance cost is worse and a cost/repro/security spike demonstrates managed value. |
| Keep public web fully alive indefinitely | Doubles renderer/input/physics/network/release QA and presents rejected visuals as product quality. | A funded product requirement proves a separate web market and assigns a permanent team/budget. |
| Simulator screenshots/frame rates as release proof | Simulator does not represent Metal GPU, thermals, touch/controller latency, memory/jetsam, haptics, or ProMotion. | Never for performance/feel; valid for UI/lifecycle/accessibility/build smoke only. |

## 16. Final release scorecard

The captain can evaluate the program without reading implementation history. Native v1 is a go only when all rows are green:

| Scorecard | Required result |
|---|---|
| Toolchain/release | Exact Unity/Xcode pins, compliant licenses, signed reproducible archive, protected CI, symbols, TestFlight and rollback proven. |
| Generated coverage | Zero visible renderer without approved Tripo provenance across all shipping scenes, catalogs, LODs, AI/ghosts and effects; no runtime primitive fallback. |
| Visual | Captain-approved A1 style then full fixed-camera deck; source/import/device diffs; no LOD pop, corrupt normal/material, missing shader, z-fight, ungrounded lighting, or forensic box/tunnel class. |
| Controls | Objective curve/yaw gates; ≥5 blind pilot gate; touch and gamepad; captain “buttery”; input+telemetry evidence. |
| Gameplay | C# fixture parity or explicit versioned deltas for runtime/track/rules/AI; both tracks/all eight ships; no major design regression. |
| Physics | Zero defined fall-through/tunneling/NaN/respawn-loop failure in PR, nightly and release series. |
| Multiplayer | C# SDK/CLI pinned; two-device/fault/latency/reconnect tests; server authority and compatibility checks; no client mutation leak. |
| Performance | Sustained physical-device 60 hot on every supported device; p95 ≤13.3 ms CPU/GPU, controlled 1% low ≥60, no post-warmup game-caused >33.3 ms. 120 advertised only on tiers meeting its separate gate. |
| Stability | Zero crash/hang/watchdog/jetsam/leak/stuck input in ≥2 h/track/tier release soaks and interruption matrix; diagnostics symbolication proven. |
| Accessibility/privacy | Safe-area phone/iPad UI, controller navigation, reduced motion/flashes/haptics, readable effects, disclosures/consent/deletion and App Store metadata accepted. |
| Process | Every landing PR `checks-passed` + BRB YES, no open P0/P1, durable evidence manifest. |

## 17. Primary references and local evidence index

### Local sources

- Forensic report and evidence: `/Users/leebarry/firstmate/data/kz-visaudit-v7/report.md`, especially sections 2–4, 7–8; sibling `screenshots/`, `gifs/`, and `evidence/`.
- Current roadmap: `/Users/leebarry/firstmate/data/kzero-plan.md`; queued multiplayer convergence: `/Users/leebarry/firstmate/data/kz-p4-plan-c5/converged-plan.md`.
- Runtime: `src/game/runtime/GameRuntime.ts:55-143`, `src/game/runtime/FixedStepDriver.tsx:48-159`.
- Track contracts: `src/game/track/compiler/artifactTypes.ts:1-29`, `src/game/track/compiler/`, `src/game/track/compiled/`.
- Steering evidence: `src/game/craft/inputSampling.ts:68-80,220-279`, `steerMapping.ts:9-37`, `tuning.ts:180-219`, `craftController.ts:425-501`.
- Visual/LOD evidence: `src/game/Scene.tsx:204-286`, `src/game/craft/craftMeshes.tsx:207-310`, `src/game/craft/PlayerCraft.tsx` AI `farOnly`, `src/game/craft/craftLod.ts:32-50`.
- Procedural visible categories: `src/game/visuals/envKit.tsx`, `trackSurfaceLife.tsx`, `Scenery.tsx`, `src/game/weapons/WeaponVfx.tsx`.
- Optimization/provenance: `scripts/optimize-assets.mjs:78-123`, `public/assets/PROVENANCE.md:33-84,136-154`, `docs/asset-overhaul-budget.md`.
- Multiplayer: `src/net/matchAdapter.ts`, `src/net/spacetime.ts`, `module/src/rules.ts`, `module/package.json`.

### Current primary external sources

- Unity editor/version/support/licensing: [Unity 6.3 support](https://unity.com/releases/unity-6/support), [6000.3.19f1](https://unity.com/releases/editor/whats-new/6000.3.19f1), [2026 license thresholds/pricing](https://unity.com/products/pricing-updates).
- Unity mobile rendering: [Metal compatibility](https://docs.unity3d.com/6000.0/Documentation/Manual/metal-requirements-and-compatibility.html), [URP rendering paths](https://docs.unity3d.com/6000.0/Documentation/Manual/urp/rendering-paths-comparison.html), [texture streaming](https://docs.unity3d.com/6000.0/Documentation/Manual/TextureStreaming.html), [mesh compression](https://docs.unity3d.com/6000.0/Documentation/Manual/configure-mesh-compression.html).
- Apple build/display/distribution: [Xcode versions and macOS requirements](https://developer.apple.com/support/xcode), [App Store SDK minimum](https://developer.apple.com/news/upcoming-requirements/), [Developer Program membership](https://developer.apple.com/support/compare-memberships/), [ProMotion](https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays), [TestFlight](https://developer.apple.com/testflight/).
- Asset tools: [Unity glTFast](https://github.com/atteneder/glTFast), [Blender license](https://docs.blender.org/manual/en/latest/getting_started/about/license.html), [Khronos KTX Software](https://github.com/KhronosGroup/KTX-Software).
- Multiplayer: [SpacetimeDB Unity support/tutorial](https://spacetimedb.com/docs/tutorials/unity/), [C# SDK](https://spacetimedb.com/docs/clients/c-sharp/), [connection/FrameTick/reconnect](https://spacetimedb.com/docs/clients/connection/).
- CI/storage/observability: [GameCI Unity Builder](https://github.com/game-ci/unity-builder), [GameCI iOS](https://game.ci/docs/github/deployment/ios/), [fastlane](https://github.com/fastlane/fastlane), [GitHub LFS billing](https://docs.github.com/en/billing/concepts/product-billing/git-lfs), [Unity Diagnostics](https://docs.unity.com/en-us/cloud/developer-data/diagnostics), [Unity Analytics pricing](https://docs.unity.com/en-us/analytics/pricing-and-billing/mau-based-pricing), [XcodeBuildMCP](https://github.com/getsentry/XcodeBuildMCP).

## 18. Conclusion

The browser build should not be cosmetically upgraded in parallel. Its audit proves the rejected look was produced by an intentionally sparse primitive world, box opponent/LOD paths, destructive one-size optimization, and a thin renderer—not by an unavoidable performance wall. The Unity pivot succeeds only if it preserves the tested simulation/track/rule ideas while refusing to preserve those presentation shortcuts.

The recommended program therefore front-loads tools, oracle capture, C# simulation/compiler, native physics and steering; proves one stunning generated ship/sector at sustained device frame time; then scales total Tripo coverage in parallel; then ports both-track AI and the C# Spacetime client; and finally hardens streaming, thermals, stability, TestFlight, and App Store release. This sequence makes “beautiful” and “60 fps” co-equal gates and gives every future claim a screenshot, frame series, provenance record, or piloting trace that can be attacked and reproduced.
