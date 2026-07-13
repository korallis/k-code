# Cross-review: kz-transform-x6 draft, reviewed by kz-transform-c2

**Reviewer:** c2 (Fable 5) · **Subject:** `/Users/leebarry/firstmate/data/kz-transform-x6/report.md` (647 lines, read in full) · **Date:** 2026-07-13
**Method:** every disputed claim re-checked against this worktree (`34ca048`), the audit (`kz-visaudit-v7`), my five research annexes (c2 report Appendix B), and fresh local probes run for this review. Where x6 is right and c2 is wrong, that is stated plainly.

---

## 1. Verdict in one paragraph

The two drafts converged independently on ~80% of the load-bearing decisions (Unity 6.3 LTS pin, URP-not-HDRP with the same official citation, IL2CPP/Metal/ARM64, 60 Hz sim with interpolated optional 120, port-contracts-not-code, PhysX-as-service with our controller math, keep the TS SpacetimeDB module + C# client, glTFast editor import with Unity-owned ASTC, fail-closed provenance, frame-time series not averages, GameCI + self-hosted Mac + fastlane + TestFlight, web freeze). That convergence is itself evidence the shared skeleton is sound. The real fights are: **repo topology** (nested vs new repo), **art-spend sequencing** (x6's one-ship vertical slice gate vs c2's early full ships wave — x6 is mostly right, with one dependency to cut), **budget method and doctrine scope** (c2 has unit math x6 lacks; x6 has spend-control ops c2 lacks; a doctrine interpretation worth ~5–8k credits needs a captain ruling), **URP posture** (Forward vs Forward+, TAA/STP, motion blur — split verdicts below), **ship LOD0 density** (x6's 30–80k regen target vs c2's fix-the-indicted-variables-first), and **roadmap completeness** (x6 misses the in-flight items and never schedules the kz-n0-fix module bugs; c2 misses an oracle-freeze milestone and had two overstated tool-readiness rows). A converged plan assembled per §6 below is stronger than either draft.

---

## 2. Scorecard by contested axis

| Axis | x6 position | c2 position | Verdict for converged plan |
|---|---|---|---|
| Repo topology | Nested `unity/KZero/` in existing repo | New `k-zero-app` repo; compiler+module stay in old | **Either works; c2 lean holds** — see §4.1 |
| Unity pin | 6000.3.19f1 exact + known-issue spike | 6000.3.x latest patch | **x6** (exact pin + spike), verify patch/issues at N0 |
| URP path | Forward default; Forward+ Ultra-only after proof | Forward+ assumed for cluster lights + GPU Resident Drawer | **x6's promotion discipline + c2's GRD dependency caveat** — §4.2 |
| AA / upscaling | SMAA or 4×MSAA; TAA off until ghosting gate; STP absent | TAA+STP default T1+ | **Merge**: SMAA baseline; STP+TAA as qualified tier mode behind x6's ghosting gate — §4.3 |
| Motion blur | Rejected (full-screen) | Allowed T2 at 60, per-object framing | **x6 wins** — §4.4 |
| Ship LOD0 | 30–80k tris, regenerate up | Reuse 16k raws, fix textures/normals/scale/LOD first, regen only on captain re-reject | **c2 first, x6 as A1 A/B arm** — §4.5 |
| Art-spend sequencing | C3 (pilots) + A1 (slice) both gate bulk; A1 depends on C2 | Ships wave early ("looks like the new game" fast) | **x6 shape, minus the A1←C2 dependency** — §4.6 |
| Credit budget | 20,500 ceiling / 3,670 reserve; category ceilings, no unit math | 5.4–8.3k envelope from observed per-task prices | **c2 arithmetic inside x6 guardrails; doctrine delta priced for captain** — §4.7 |
| Controls gates | 5 blind pilots, median ≥4.5, ≥80% preference, wall-contacts/km −30%, lap ≤+3%, numeric rise bands | ≥3 sessions incl. captain ≥4/5, overshoot/settle/envelope/jerk vs baseline | **x6 protocol, c2 numbers-from-baseline; drop x6's pre-committed 180–260 ms band** — §4.8 |
| Multiplayer sequencing | NET1 after PF after AI2 (late) | Early iOS IL2CPP connectivity spike | **c2** — pull the spike to Wave 1–2; x6's own risk register supports it — §4.9 |
| Roadmap reconciliation | Phase-level; misses kz-funplay, PR #25, kz-n0-fix scheduling | Item-level vs live backlog | **c2**, plus x6's web-retirement gate — §4.10 |
| Perf gate numbers | p95 ≤13.3 ms, zero >33.3 ms post-warmup, 1% low ≥60; 120-mode equivalents | Series + percentiles, no headroom threshold | **x6** |
| Provenance enforcement | Build fail + runtime fail-closed (branded error, never a box); renderer→prefab GUID→record graph | Build-time coverage test + manifest | **x6's runtime fail-closed added to c2's manifest v2** |
| Oracle | O1 freeze-and-export milestone first | Per-PR fixtures, no single freeze | **x6** |
| Tools inventory | Probe-grounded ("nothing is installed"); adds Blender, SpacetimeDB BSL license check, analytics/privacy | Priced rows + captain checklist; overstated two ✅ rows | **Merge; c2 self-corrections in §5.2** |

---

## 3. Material agreements (no further argument needed)

Both drafts, independently: HDRP-impossible-on-iOS with the same Unity manual citation; Built-in deprecated; sim purity and tick contract carried verbatim; controller math ported as *our* physics with PhysX demoted to raycast/collision service and manual `Physics.Simulate`; Rapier constants are hypotheses, not gospel (x6: "do not copy 0.82/0.92 as sacred"; c2: "re-derive damping from feel targets"); determinism scope stays same-build/same-device and ghosts ship as recorded pose streams; the TS server module survives unchanged with `spacetime generate --lang csharp`; solo-never-connects carries; glTFast editor-time import of raw 4k GLBs with Unity-owned ASTC and no meshopt/KTX2 runtime path (the entire `optimize-assets.mjs` failure class deleted rather than fixed); uniform-scale-only normalization (both cite `craftLod.ts:32-50` non-uniform scale as a defect); LODGroup dithered cross-fade; per-asset structural + visual-diff gates with committed evidence; provenance as an enforced contract, not a celebration document (both quote `PROVENANCE.md:136-154` against itself); simulator is never perf/feel evidence; TestFlight internal per merge; captain-only checklists nearly identical (Apple enrollment, license-tier attestation, ASC API key, device matrix, build Mac, budgets).

Also credit where due — **x6 catches a real code fact c2 missed:** debug/test input overrides merge *after* smoothing, so automation can bypass the player shaping path. Verified this review at `src/game/craft/inputSampling.ts:262-278` (`quantizeInput(mergeInput({...smoothed...}, override))` — override steer replaces the smoothed value). Consequence adopted for the converged plan: Unity bot/QA input must route through the same shaping stages or be explicitly flagged in telemetry, and pilot evidence must record post-shaping intent.

And x6's **toolchain probe is corroborated**: I re-ran it on this lane's Mac for this review — `xcodebuild` resolves to CommandLineTools only, and `unity-hub`, `git-lfs`, `spacetime`, `fastlane`, `simctl` are all MISSING. Their "N0 is real procurement, not housekeeping" framing is correct, and it exposes an error in my own draft (§5.2 below).

---

## 4. Disagreements argued on the merits

### 4.1 Repo topology: nested `unity/KZero/` (x6) vs new repo (c2)

x6's two arguments: avoids a "disruptive repository move", and keeps legacy tests colocated as the parity oracle. The first is inverted — there is no move; a new repo starts empty and the old repo keeps compiler/module/web exactly where they are (c2 §9.3). The second doesn't hold technically: the oracle crossing is **exported JSON fixtures + goldens** (x6's own O1 milestone!), which are artifacts, not imports — they can be consumed from any repo, and x6's plan already copies them into fixture files rather than importing TS. What nesting actually costs, from my toolchain annex (B.5, cited): Unity Library/LFS churn and `.gitattributes`/merge-driver complexity land in the web repo's history; every web PR's CI has to path-filter around Unity; LFS quotas are per-owner so there is **no quota benefit** to nesting; and clone size grows for both audiences. What nesting buys: single-PR changes that touch artifact schema + exporter + importer together (real, but rare and manageable with a versioned artifact contract — which both drafts already require for other reasons).
**Verdict:** genuine judgment call; c2's separate repo remains the better default (CI noise, review ergonomics, LFS hygiene), with x6's coordination concern answered by versioning the exported artifact format. If the captain prefers one repo to reduce account/plumbing overhead, nesting is workable — but then adopt x6's own hygiene rows (path-scoped CI, LFS patterns, YAML merge config) on day one.

### 4.2 URP rendering path: Forward-first (x6) vs Forward+ (c2)

x6 cites Unity's rendering-path comparison to justify Forward default. Two corrections to how that citation is used: (1) the same page rates **both Forward and Forward+ as low-impact on mobile** — the documented costly path is Deferred (G-buffer, no MSAA), which both drafts already reject; (2) x6's own asset program (A5/A6, "GPU instancing/SRP Batcher", "GPU Resident Drawer/indirect paths enabled only after physical-device series") collides with a Forward-only baseline, because **GPU Resident Drawer requires Forward+ or Deferred+** (c2 annex B.4, Unity GRD manual). If the dense generated trackside kit needs GRD to hold draw calls, Forward+ must qualify on at least the tiers that render that density — otherwise the fallback is classic SRP-batched instancing, which should be named in the plan rather than discovered in a failing PR.
**Verdict:** adopt x6's measured-promotion discipline (Forward is the T0 floor; nothing ships on Forward+ without a device series), but make the R1/A1 spike explicitly test **Forward vs Forward+ with the A1 sector's real instancing load**, and pre-declare the two outcomes: Forward+ qualifies (→ GRD + cluster neon lights on T1/T2+, c2 §3) or it doesn't (→ SRP-batcher instancing everywhere, neon stays emissive+bloom on all tiers). Don't leave it "experimental on Ultra someday".

### 4.3 TAA / STP / upscaling

x6: SMAA or 4×MSAA baseline, TAA off until a chase-camera ghosting test passes; STP never mentioned. c2: TAA+STP default on T1+. Facts: STP is Unity's supported mobile upscaler (compute-capable devices), **requires TAA**, and ships in Unity's own mobile demo at min-spec iPhone 13 (B.4); x6's alternative for constrained tiers is raw render-scale 0.75–0.85 with no reconstruction, which burns sharpness STP exists to recover. Meanwhile x6's ghosting concern is legitimate for exactly this game (fast parallax, thin emissive rails), and c2 under-gated it. One more tension inside x6: "4×MSAA or SMAA" on the same tier as SSAO — Unity's own AA guidance (cited in both annex sets) says MSAA is only cheap on tile GPUs when nothing forces a depth resolve; SSAO forces one. MSAA+SSAO together is the one combination neither doc supports.
**Verdict (merge):** baseline AA = SMAA (FXAA on T0); STP+TAA is a **qualified tier mode** gated by x6's scripted chase-camera ghosting test (thin-rail parallax scene, recorded at speed); if it passes on a tier, that tier gets render-scale + STP reconstruction (c2's lever); if it fails, that tier stays SMAA at higher native scale. MSAA only on tiers running zero depth-based post.

### 4.4 Motion blur — concede to x6

c2 allowed evaluated motion blur on T2, framed around per-object velocity. That framing was a carry-over from the pre-pivot three.js plan (TSL motion blur is per-object opt-in); **URP's Motion Blur post effect is camera-motion only**, so the "blur the world, keep the craft sharp" design c2 described isn't what URP ships. Given that, plus x6's readability/photosensitivity argument, the GRID-Legends precedent (ships motion blur only in its 30/40 fps modes — c2's own annex), and the existing feel package already delivering speed sensation (speed lines, FOV punch, camera work carried in both plans): **x6 wins**. Full-screen motion blur is out; speed perception stays with mesh/VFX/FOV cues; at most a photo-mode/camera-cut nicety later. (Verify the URP camera-only claim once at R1; it strengthens, not weakens, the rejection.)

### 4.5 Hero ship density: regenerate to 30–80k (x6) vs rehabilitate the 16k raws first (c2)

The audit indicts, in order: AI boxes, LOD box-pop, **texture downscale 4k→1k, i8 normal quantization, non-uniform scale** — and separately notes 16k AI-mesh topology reads soft against a Forza-class bar (audit §2.2 lever row). x6 jumps to "LOD0 roughly 30–80k, subject to device proof", which means regenerating all eight hulls before knowing whether the indicted variables were the problem. c2's sequence isolates variables: import the existing 4k raws with correct normals/uniform scale/real LODs/shadows/2k ASTC, put one on a device, and let the captain judge silhouette density with everything else fixed. Regeneration cost isn't the issue (8 × ~70 cr is cheap); **approval churn and attribution are** — if the captain re-rejects after a full regen, nobody knows whether topology, texture, or lighting was the fix.
**Verdict:** A1 vertical slice carries **two arms**: (a) rehabilitated 16k raw, (b) one regenerated ~40–60k-face-limit variant of the same family. Captain picks on-device. Then the ships wave spends accordingly. This is strictly more information for ~70 credits.

### 4.6 Art-spend sequencing: x6's gates are right; one dependency is wrong

x6 gates bulk generation on C3 (pilot-passed controls) *and* A1 (captain-approved vertical slice), with A1 **depending on C2** (candidate steering tune) — rationale: "bad steering must not be hidden under new art." The principle is right for the *fun* verdict and for bulk spend; c2's own plan front-loaded a full 8-ship wave to give the captain an early fidelity signal, which risks 8× regen if the captain rejects the pipeline look — x6's one-ship+one-sector A1 gets the same signal at ~1/8 the spend. **Adopt A1.** But the A1←C2 edge is unnecessary: A1 is a *visual* go/no-go (fixed cameras, turntables, device captures); it does not require candidate steering — the S1-parity baseline controls drive the capture laps fine, and x6's own A1 acceptance row lists no feel criterion. Cutting that edge lets the art-pipeline lane (A0→A1) run **in parallel** with the controls lane (C1→C3) instead of behind it, pulling the captain's first "this looks like the new game" moment weeks earlier while still keeping **bulk** spend behind both gates.
**Verdict:** adopt x6's Wave structure with A1 dependencies reduced to {R1, A0, P1}; bulk waves (A2–A6) still require C3 **and** A1.

### 4.7 Credit budget: method vs guardrails — and the doctrine question that drives a ~5–8k swing

Refutation of x6's method: the 20,500-credit program presents eight category ceilings **with no per-task unit derivation anywhere** — no price per text/image/multiview task, no LOD/retexture task costs, no attempt-count assumptions. The ledger in `public/assets/PROVENANCE.md` (observed: 50–60 cr/generation on this account) and the official price sheet (c2 annex B.3: H3 text 20+10 detailed, image 30+10; rig 25; retarget 10; `texture_model` 10–20; refunds on failure; concurrency caps) were available and unused. There is also a small internal inconsistency: a "3,670 protected reserve" alongside a "stop below 3,500" tripwire — two different floors. None of this makes 20,500 *wrong* as a ceiling; it makes it unauditable as an estimate.
What x6 gets right that c2 lacked: **spend-control operations** — predeclared asset ID + max attempts per job, daily ledger reconciliation against Tripo task history, an automation stop on divergence. Adopt wholesale.
The real driver of the 20,500-vs-8,300 gap is **doctrine interpretation**, and it needs a captain ruling because the two drafts read the same sentence differently:
- **Track surface:** both agree the compiled ribbon stays gameplay authority with art over it — but x6 generates a full modular **road-skin/rail/tunnel mesh kit** (its 6,000-cr line), while c2 generates surface *hardware* (pads/strips/gates/trim) plus generated PBR texture sets on the ribbon. Priced with c2's unit math, x6's fuller skin scope adds ≈ +2–3k credits.
- **UI chrome:** x6 requires every decorative HUD/menu frame and icon to be a Tripo mesh or a render of one. The audit's own truth table — which the captain seeded and both drafts treat as binding — marks UI plates "Menu OK as 2D" (audit §3). c2 followed the audit. If the captain wants x6's stricter reading: ≈ +1–2k credits.
**Verdict:** converged budget = c2's unit-derived arithmetic (base ≈3.0–3.9k, ×1.5 retries, +40% program contingency → 5.4–8.3k) **plus** the two interpretation options priced above (doctrine-max ≈ 8.5–13k), governed by x6's category ceilings and reconciliation ops, with one reserve floor (recommend x6's 3,670, delete the 3,500 second floor). Every scenario leaves >11k remaining.

### 4.8 Controls acceptance: adopt x6's protocol, not its pre-committed numbers

x6's pilot protocol is better than c2's: blind A/B/baseline comparison, per-scheme coverage (touch and gamepad rated separately), preference threshold (≥80%), and two outcome metrics c2 didn't have — **wall contacts/km −30%** and **median clean-lap ≤ +3%** (guards against "smooth but slow"). Adopt all of it. Two pushbacks: (1) x6 hard-codes 10–90% rise 180–260 ms / return 120–180 ms / reversal 300–420 ms as *gates* in §6.4 after calling them "initial candidates" in §6.2 — pre-committing response-shape numbers before the C0/C1 baseline exists repeats the exact mistake that produced today's 3.2/s constant (a plausible number nobody validated). Converged plan: bands are *derived* from baseline telemetry + first pilot round, then frozen as gates. (2) "At least five blind pilots" on a solo-captain project is an ops question, not a design one — name the pilot pool (captain + BRB agents + any recruitable humans) or scale the threshold to the pool honestly. c2's session structure (baseline capture on the parity build first, so before/after is attributable) is kept.
On substance both drafts prescribe the same fix — expo/deadzone shaping, critically-damped or slew-limited command filtering, speed-scheduled authority materially below today's 82%-at-terminal, time-constant-based lateral grip instead of 0.92/tick, yaw-overshoot damping instead of the 1.5× counter-steer slam. No fight there; the mechanism diagnosis is byte-identical down to the file:line cites.

### 4.9 Multiplayer sequencing: pull the iOS connectivity spike forward

x6 sequences NET1 (SDK + adapter shell) behind PF, behind AI2, behind the full art program — the C# SDK first touches a real iPhone in Wave 5. Yet x6's own risk register lists "Spacetime C# SDK/CLI mismatch or IL2CPP stripping — medium/high" and its §7 mandates an IL2CPP/linker/AOT device test. c2's annex adds the concrete precedent: the SDK needed WebGL-specific fixes as recently as v2.3.0 and its docs carry **no explicit iOS support statement** — and note the version-numbering trap x6 itself flags is confirmed by c2's own data (repo npm client `spacetimedb@2.6.0` vs server/CLI release v2.3.0: the numbers genuinely don't correspond). If the SDK has an iOS-shaped hole, discovering it after the entire art program is a schedule disaster; discovering it in week 1 is a footnote (self-host bridge, SDK patch, or vendor escalation, all cheap early).
**Verdict:** keep x6's NET1–NET3 order for the *feature* work, but add a **Wave-1 device spike** (one scene, pinned SDK, connect/subscribe/reducer round-trip on IL2CPP hardware, then throw it away). ~1 agent-day, retires a program-shaped risk.

### 4.10 Roadmap reconciliation: x6 reconciles phases, not the live queue

x6's §12 maps the P1–P6 phase plan and the "G0/smooth gate + N0 fixes" line, but never mentions: **kz-funplay** (in flight, with a binding captain bar), **PR #25** (open now — captain-bound pilot evidence), or a scheduled home for the **three latent N0 module bugs** (`data/kz-p4-plan-c5/converged-plan.md`) — its "fold into N0/C1/C2/NET" row points at its own N0 milestone, which is *tool bootstrap* and contains no module work; its PF/NET rows don't list the fixes either. Those module bugs are inherited by **every** future client including the C# one, and the module is the single component both drafts agree survives unchanged — fixing it is the rare work item that is valid today, tomorrow, and in both repos. c2 schedules it as an explicit early PR in the old repo (zero file overlap with any Unity lane). Also adopt-from-x6 here: the **web online-endpoint retirement gate** (30 crash-free production days post-v1) is a better end state than c2's indefinite freeze; c2's amendment: the *static* solo demo's marginal cost is ~zero, so its retention is a one-line captain preference, while the online endpoints are the real liability and get x6's gate.

---

## 5. Corrections

### 5.1 Refutations / corrections of x6 (each with the evidence)

1. **Budget lacks unit derivation and has two reserve floors** (§4.7). Not fatal; unauditable.
2. **A1←C2 dependency is unjustified by its own acceptance criteria** (§4.6); it serializes the two workstreams the captain most wants parallel.
3. **UI-chrome doctrine extension contradicts the binding audit's own truth table** (audit §3 "UI plates … Menu OK as 2D") — legitimate as a *question*, wrong as an assumed requirement (§4.7).
4. **Forward-only baseline conflicts with its own GRD/instancing ambitions** (GRD requires Forward+/Deferred+; §4.2).
5. **MSAA+SSAO on the same tier is the one AA combination the cited docs warn about** (§4.3).
6. **STP, Mesh LOD (Unity 6.3's import-time auto-LOD with shared vertex buffers), Adaptive Performance Apple provider, GPU occlusion culling, memoryless render targets, the 8-GB HD-texture-pack gate, and the 120/60/40/30 divisor ladder are all absent** from x6's rendering/perf sections — each is a cited, shipping mechanism in c2's annex B.4 that the converged plan should keep.
7. **Pre-committed steering rise-time bands as gates** before any baseline exists (§4.8).
8. **In-flight roadmap items unreconciled** — kz-funplay, PR #25, kz-n0-fix scheduling (§4.10).
9. **GameCI "v5"**: c2's annex cites unity-builder@v4 as current (game.ci docs); x6 gives no version citation. Minor — pin whatever N2 verifies; flagged so nobody "upgrades" to a version that may not exist.
10. **Late first device contact for the SpacetimeDB C# SDK** despite its own medium/high risk rating (§4.9).
11. Small internal slip: §1.1 claims all of `threejs-game-director` etc. were "used", while §17's reference list shows no output from them — cosmetic, but under an evidence doctrine, claimed-loaded-unused should be labeled as such (c2's Appendix C models this).

### 5.2 Corrections x6 lands on c2 (owned here, to be fixed in the converged plan)

1. **c2's §10 overstated tool readiness.** Rows 7–8/23 marked Simulator/XcodeBuildMCP "✅ available"; this review's probe shows the lane Mac has **CommandLineTools only — no Xcode.app, no simctl, no unity-hub, no git-lfs, no spacetime, no fastlane**. x6's "N0 is real procurement" framing is correct and c2's P0 milestone under-scoped it.
2. **No oracle-freeze milestone.** c2 relied on per-PR fixture exports; x6's O1 (tag web state, export canonical fixtures/goldens/tuning/artifacts once, before any shared-schema change) is strictly better program hygiene. Adopt as the first milestone alongside tooling.
3. **No runtime fail-closed art path.** c2's coverage test is build-time only; x6's "missing art blocks scene entry with a branded error — never a primitive fallback" closes the gap where a bad build or load failure re-creates the Amiga class at runtime. Adopt.
4. **Motion blur allowance was wrong for URP** (§4.4).
5. **Weaker pilot protocol** — no blind A/B, no preference threshold, no wall-contact/lap-time outcome metrics (§4.8).
6. **No Unity known-issues spike** on the exact pinned patch (x6 cites a Metal command-buffer-timeout freeze + importer crash on 6000.3.19f1's known-issues list — unverified here, but the spike-before-lock policy is right regardless).
7. **SpacetimeDB license class missed.** c2 priced Maincloud but never flagged the BSL 1.1 / additional-use-grant question for production; x6's captain-legal checkbox is correct. (c2's own data reinforces the related version-trap: npm 2.6.0 vs server 2.3.0.)
8. **Spend-ops discipline** (attempt caps, daily reconciliation, divergence stop) absent from c2's §14. Adopt.
9. **c2's bulk-first ships wave** risked 8× regen ahead of a pipeline go/no-go (§4.6) — A1 replaces it.
10. Minor: x6's per-craft-race "no oscillating frame target" rule and its 20%-headroom p95 gate numbers are tighter than c2's unquantified governor promise; adopt both.

---

## 6. What the converged plan should take from each

**Skeleton:** c2's report structure (ground truth → direction → architecture → port → assets → controls → net → stability → toolchain → tools → web → reconciliation → milestones → budget → risks → rejected) with x6's O1/A1 milestones and universal-gate wording spliced in.

**From x6, adopt:** O1 oracle freeze; A1 one-ship+one-sector captain gate before bulk spend (dependency trimmed per §4.6); runtime fail-closed provenance + renderer→prefab-GUID→record enforcement wording; blind-pilot protocol with preference/wall-contact/lap-time outcome gates (numbers derived from baseline, not pre-committed); p95 ≤13.3 ms / zero >33.3 ms post-warmup / 1%-low ≥60 gate numbers and the 120-mode equivalents; injected skipped-frame fall-through patterns + minimum-signed-distance telemetry; Forward-first with pre-declared Forward+ promotion test; TAA ghosting gate; full-screen motion-blur rejection; exact-patch pin + known-issues spike; SpacetimeDB BSL legal checkbox + CLI/SDK version-match caution; credit spend-ops (attempt caps, reconciliation, single reserve floor); evidence directory convention (`docs/native/evidence/<milestone>/<build>/`); release scorecard (§16); web online-endpoint retirement after 30 crash-free days; Blender-pinned as optional cleanup; the input-override-bypasses-shaping fix requirement.

**From c2, keep:** unit-derived credit arithmetic + official Tripo price/mechanics table (B.3) with the doctrine-delta options priced for the captain; the URP/Metal mechanism set x6 lacks (STP, Mesh LOD, AP Apple provider thermal ladder, GPU occlusion, memoryless RTs, ASTC ladder + 8 GB HD-pack gate, ProMotion divisor ladder, OnDemandRendering, Enhanced Determinism + world-recreate, recorded-pose ghost citations); the costed CI analysis (self-hosted primary, ubuntu-export/macOS-finish fallback with $/min, Codemagic-blocked-on-Personal, LFS-bandwidth-vs-Actions caching); the early SpacetimeDB iOS device spike; the item-level roadmap reconciliation (kz-funplay disposition, PR #25, kz-n0-fix as an explicit early old-repo PR, op-service-account carry); the A1 two-arm ship-density A/B (§4.5); separate-repo default (§4.1, captain-overridable); Appendix-C-style honest skill/tool ledger.

**Open questions for the captain (merged, deduplicated, with what each costs):**
1. Doctrine scope ruling — track-skin meshes vs textured ribbon (+≈2–3k cr) and 3D UI chrome vs audit-sanctioned 2D (+≈1–2k cr).
2. Device floor (both drafts: decide after A1 on candidate hardware; support nothing that can't hold 60 hot).
3. Unity license tier attestation (both; x6 adds the contractor-finances contagion note — keep).
4. Repo topology preference (§4.1).
5. Web static-demo retention vs full retirement (online endpoints retire per x6's 30-day gate either way).
6. Pilot-pool composition for the blind protocol (§4.8).
7. kz-funplay / PR #25 disposition this week (c2 §15 Q4 stands).
8. Account identity (anonymous vs Sign in with Apple before external beta — x6 §14.1.3, adopt as stated).

---

*Bottom line: x6 is a rigorous, execution-shaped draft whose spend-gating, oracle discipline, and acceptance numbers should survive into the converged plan; its budget method, Forward-only baseline, late network spike, pre-committed feel bands, and roadmap gaps should not. c2 supplies the unit economics, the Unity/Metal mechanism depth, the costed toolchain, and the live-queue reconciliation; it takes from x6 the A1 gate, O1 freeze, runtime fail-closed art, and several honesty corrections logged in §5.2.*
