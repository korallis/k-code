# K-ZERO Forensic Visual Audit (kz-visaudit-v7)

**Date:** 2026-07-13  
**Worktree:** `/Users/leebarry/.treehouse/k-zero-7c110f/2/k-zero` @ detached `34ca048`  
**Mode:** REPORT ONLY — no fixes applied  
**Reference bar (Captain, binding):** **Forza Motorsport / GTA 5 class** — high-fidelity full 3D, beautiful and stunning at 1080p/4K. Browser/WebGL is the platform, but the bar is not “good enough for web”; it is “push the boundary of what WebGL allows.”  
**Captain doctrine:** entire game must be fully 3D with **real generated assets** (Tripo API primary). **Any player-visible primitive/procedural/low-poly stand-in is a violation.**  

---

## 0. Method (what was actually done)

1. Installed deps; ran Vite at `http://localhost:5173`.
2. Drove Chrome via `chrome-devtools-axi` at **viewport 1920×1080**, captured PNG stills + drive GIFs under this report directory.
3. Measured live canvas buffer size, `devicePixelRatio`, `__KZERO_RENDER_BUDGET__`, WebGL samples.
4. Inspected runtime GLBs with `@gltf-transform inspect` (raw Tripo vs optimized ships).
5. Source-traced every major visible category (ships, AI LOD, pickups, pads, scenery, weapons VFX, renderer).
6. Read `public/assets/PROVENANCE.md` and compared claims vs code vs screenshots.
7. Loaded AAA skill render recipes (threejs-aaa-graphics-builder) for the “what a browser racer should use” column.

**Evidence root:** `/Users/leebarry/firstmate/data/kz-visaudit-v7/`  
- `screenshots/` — primary 1080p captures  
- `gifs/` — motion probes  
- `evidence/` — GLB stats CSV, code excerpts, inspect dumps  
- `screenshots/prior-docs/` — earlier crew screenshots (mostly **phone aspect ~757×1280 / 1200×2029**, not 1080p desktop)

---

## 1. Resolution / DPR (Finding #1)

### Measured (this session)

| Metric | Value | Evidence |
|--------|-------|----------|
| Window | 1920×1080 | `chrome-devtools-axi resize 1920 1080` |
| `devicePixelRatio` | **1.0** (Chrome session; not a Retina host path) | eval in `screenshots/neon-reopen-measure.png` session |
| Canvas CSS | 1920×1080 | same |
| Canvas buffer | **1920×1080** (ratio 1.0) | same |
| MSAA samples | 4 | WebGL `SAMPLES` |
| Live tri peak | ~109k | `__KZERO_RENDER_BUDGET__` |

### Code (authoritative on Retina / 4K)

```284:286:src/game/Scene.tsx
        gl={{ antialias: true }}
        dpr={[1, 1.75]}
```

| Lever | Current | Forza / GTA 5 class | Closing the gap in WebGL |
|-------|---------|---------------------|---------------------------|
| Output resolution | Canvas CSS fills window; **DPR hard-capped at 1.75** | Native 1080p/1440p/4K framebuffer; no artificial 0.875× of Retina | Set `dpr` to `Math.min(devicePixelRatio, 2)` desktop (optionally 1.5 mobile), profile GPU; expose quality preset. On a 2× Retina 1080p panel this currently yields **~1680×945** internal res — soft/“Amiga” at any desktop. |
| Antialiasing | Default WebGL MSAA via `antialias: true` (measured 4 samples) | TAA/MSAA high + optional temporal resolve | Keep MSAA; add SMAA/TAA via post stack on high quality; optional supersample path. |
| 4K | No quality tier | 4K native | Same as DPR; add explicit 4K preset with reduced post/shadow cost. |

**Verdict:** On this capture host DPR=1 hid the cap. **The cap is still a first-class defect for any high-DPI display.** Evidence: code line above + live measure dump in session eval (saved in method notes).

---

## 2. Polygating diagnosis (ships “random polygon glitches”)

### 2.1 What the captain likely saw (reproduced)

| Symptom class | Cause (named) | Severity | Evidence |
|---------------|---------------|----------|----------|
| **A. AI opponents are literal boxes** | `AiCraft` forces `CraftVisualMesh … farOnly` → `CraftSilhouette` = **one `boxGeometry` + two thruster circles** | **Critical** in Race mode | Code: `src/game/craft/PlayerCraft.tsx` ~1257; GIF `gifs/race-ai-box-silhouettes.gif`; stills `screenshots/race-ai-spawn.png`, `race-ai-field-spawn.png`, `race-ai-mid.png` |
| **B. Player far LOD pops to boxes** | `<Detailed distances={[0, 32, 75]}>` → third LOD = same `CraftSilhouette` box | High (mid/far field) | `src/game/craft/craftMeshes.tsx` 298–310; evidence excerpt `evidence/craftMeshes-LOD-excerpt.txt` |
| **C. Hero GLB looks faceted / “poly” up close** | Tripo AI mesh (~15–17k tris) + **meshopt quantize** (POSITION i16, NORMAL **i8**) + **4K→1K** textures + **non-uniform scale** in `getCraftFarLodTransform` | High (hero closeups) | Stills: `screenshots/race-ai-mid.png`, `neon-ship-heavy-spawn.png`, `neon-boost-pad-close.png`; GLB table §2.2 |
| **D. Meshopt “corruption”?** | **Not catastrophic geometry break** — no missing normals; modest tris drop; primary hit is **texture resolution + normal quantization** | Medium (quality loss, not random holes) | `evidence/glb-stats.csv`, `evidence/glb-inspect-raw-vs-opt.txt` |

**Primary polygating culprit (field):**  
**Race AI deliberately renders seven opponents as procedural boxes** (`farOnly`), not Tripo GLBs. That alone makes the pack look like 1990s low-poly placeholders.

**Secondary polygating culprit (hero):**  
Optimized Tripo ships are still faceted AI meshes; runtime force-recompress (`@gltf-transform optimize --compress meshopt` + KHR quantization + 1k textures) **amplifies** faceting/normal noise. Raw sources for five ships still exist under `public/assets/raw/tripo/ships/` with **4096²** textures and f32 attributes.

**Not the main story:** random GLB “broken triangles” / NaN geometry. Inspect showed valid meshes.

### 2.2 Raw vs optimized GLB (meshopt pass)

Pipeline: `scripts/optimize-assets.mjs` → `npx @gltf-transform/cli optimize … --compress meshopt` (and PROVENANCE documents separate **resize 1024** for production art). Runtime `public/assets/ships/*` **byte-identical** to `public/assets/opt/tripo/ships/*`.

| Asset | Tris | Verts | Textures | Attrs | Size | Extensions |
|-------|------|-------|----------|-------|------|------------|
| RAW razor | 17,430 | 11,586 | **4096²** ×3 | f32 pos/nrm | 2.48 MB | none |
| OPT razor | 15,764 | 10,743 | **1024²** ×3 | i16 pos, **i8 nrm** | 432 KB | meshopt+quantize |
| RAW viper | 16,605 | 11,311 | 4096² | f32 | 2.70 MB | none |
| OPT viper | 16,001 | 11,002 | 1024² | i16/i8 | 492 KB | meshopt+quantize |
| RAW pulse | 16,283 | 12,855 | 4096² | f32 | 3.05 MB | none |
| OPT pulse | 16,095 | 12,758 | 1024² | i16/i8 | 597 KB | meshopt+quantize |
| RAW nova | 15,811 | 11,834 | 4096² | f32 | 3.07 MB | none |
| OPT nova | 15,015 | 11,423 | 1024² | i16/i8 | 601 KB | meshopt+quantize |
| RAW bulwark | 16,525 | 12,244 | 4096² | f32 | 3.81 MB | none |
| OPT bulwark | 16,347 | 12,151 | 1024² | i16/i8 | 707 KB | meshopt+quantize |
| OPT agile/balanced/heavy | ~15–16k | — | 1024² | i16/i8 | ~550–606 KB | meshopt+quantize |

**Full CSV:** `evidence/glb-stats.csv`  
**Inspect dump (razor):** `evidence/glb-inspect-raw-vs-opt.txt`

| Lever | Current | Forza/GTA class | WebGL close-gap |
|-------|---------|-----------------|-----------------|
| Hero mesh density | ~16k tris, AI-generated topology | 50k–200k+ authored LODs, clean hard-surface | Higher Tripo face_limit + human retopo OR kitbash; 3 LODs of real GLBs (not boxes) |
| Textures | 1k after force downscale from 4k | 2k–4k hero albedo/ORM/normal | Ship near LOD: keep **2k** (or selective 4k albedo); far: 512–1k |
| Quantization | i8 normals | full float or careful compress | Soften meshopt (disable quantize on normals for hero) or use Draco with higher precision |
| Opponents | **boxes** | full car models | Same hero GLB family for AI with mid/far generated LODs |

### 2.3 Motion evidence

- Solo drive probe: `gifs/neon-drive-polygate-probe.gif` (+ `.mp4`)  
- Race AI field: `gifs/race-ai-box-silhouettes.gif`  
Frame folders: `gifs/frames-neon-drive/`, `gifs/frames-race-ai/`

---

## 3. Provenance truth table = **VIOLATION INVENTORY**

Captain doctrine: **anything player-visible that is not a real generated 3D asset is a finding.**  
PROVENANCE.md already admits many “KEEP procedural” decisions — those are **violations**, not just notes.

| Category | Manifest claim | Actually rendered | Tripo-generated? | Violation? | Evidence |
|----------|----------------|-------------------|------------------|------------|----------|
| **Hero ships (player near/mid)** | Tripo image→3D, meshopt+1k | Yes, GLB under `public/assets/ships/ship-*.glb` | **Yes** (optimized) | Soft: quality/quantize/1k only | `screenshots/neon-ship-*-spawn.png`, ship-select `screenshots/ship-select-*.png` |
| **Hero ships (player far ≥75 m)** | Far = procedural silhouette (KEEP) | **Box + 2 discs** | **No** | **YES** | `craftMeshes.tsx` Detailed LOD |
| **AI opponents (Race)** | (implied budget) | **Always farOnly boxes** | **No** | **YES — critical** | `PlayerCraft.tsx` AiCraft; race stills/GIF |
| **Ghost crafts** | procedural path | FamilyMesh procedural primitives | **No** | **YES** | `craftMeshes.tsx` `CraftVisualSimple` / ghost path |
| **Pickup pads / item drops** | Track-surface life KEEP procedural; pads not in Tripo ledger | Cylinder + torus + **octahedron** crystal | **No** | **YES — captain confirmed** | `envKit.tsx` `PickupPadMesh`; code excerpt `evidence/PickupPadMesh-excerpt.txt`; PROVENANCE keep table |
| **Boost pads** | KEEP procedural chevrons | Flat emissive **boxes** + instanced box chevrons | **No** | **YES** | `trackSurfaceLife.tsx` `BoostPadSurfaces`; `screenshots/neon-boost-pad-close.png`, `neon-razor-mid5.png` |
| **Recharge strips** | KEEP procedural mint plates | Box plates | **No** | **YES** | `trackSurfaceLife.tsx`; track defs |
| **Start grid pads** | KEEP procedural | Box chevrons / plates | **No** | **YES** | `envKit.tsx` StartGrid; spawn stills |
| **Weapon projectiles** | (not listed as Tripo) | Pooled **spheres/cones/cylinders/rings/octahedra** | **No** | **YES** | `WeaponVfx.tsx` geometries; `evidence/code-geometry-inventory.txt` |
| **Weapon impacts / shield / EMP** | presentation VFX | Primitive instanced meshes | **No** | **YES** | same |
| **Finish gate** | Tripo | GLB `opt/tripo/props/finish-gate.glb` | **Yes** | No (sparse landmark) | PROVENANCE + GLB stats |
| **Landmarks (Neon spire)** | Tripo | GLB landmark-tower | **Yes** | No (sparse) | |
| **Landmarks (Foundry stack/crane/chimney)** | Tripo | GLBs | **Yes** | No (sparse) | `foundry-drive-*.png` may show crane silhouettes |
| **Pit garage / grandstand** | Tripo sparse | GLBs | **Yes** | No (sparse) | |
| **Near pylons** | KEEP procedural | Instanced **cylinders/boxes** | **No** | **YES** | `Scenery.tsx` NearPylons; neon/foundry stills (cyan sticks) |
| **Gantries** | KEEP procedural | Boxes | **No** | **YES** | `envKit.tsx` GantryMesh |
| **Mid buildings / skyline masses** | KEEP procedural | **Unit boxes** scaled | **No** | **YES — skyline reads Amiga** | `Scenery.tsx` MidBuildings; `neon-razor-mid3.png` |
| **Billboard frames** | KEEP procedural frames; faces = gen 2D | Box frames + textured planes | Frames **No** | **YES** (frames) | Scenery billboards |
| **Skyline ring / dome** | gen plates + procedural cylinder | Huge cylinder + 2D plates | Structure **No** | **YES** | Scenery |
| **Foundry tunnel arches** | (not Tripo) | **Floating blue box panels** | **No** | **YES — extreme** | `screenshots/foundry-drive-3.png` |
| **Track ribbon surface** | asphalt PBR CC0 | Compiled ribbon + Asphalt006 2K maps | **No** (texture not model) | Surface is not a “model”; still not “generated craft-quality mesh” | Close asphalt grain in all race stills |
| **Walls / lattice rails** | compiled geometry | Track mesh + emissive edges | **No** | Authored track — acceptable as world geo if high quality; currently simple | stills |
| **Stars / rain** | drei Stars + points | Point sprites | **No** | **YES** as visible filler | Scene.tsx |
| **HDRI env** | Poly Haven CC0 | Reflection only (`background={false}`) | **No** (env map) | OK as lighting, not a model | Scene.tsx CircuitEnvironment |
| **UI plates** | Grok Imagine 2D | 2D | N/A | Menu OK as 2D | ship-select / title stills |

### Explicit non-generated inventory (player-visible)

1. All **pickup pad** meshes (base/ring/crystal)  
2. All **boost pad** floors + chevrons  
3. All **recharge strip** floors  
4. All **start grid** pads  
5. All **weapon/utility VFX** meshes  
6. All **AI craft** visuals in Race  
7. Player **far LOD** silhouettes  
8. Ghost craft meshes  
9. Near **pylons**, **gantries**, **mid buildings**, billboard **frames**, start structures  
10. Foundry **tunnel box rings**  
11. Stars / rain particles  
12. Large share of skyline massing  

**Tripo-generated (actual, sparse):** 8 ships (near/mid only) + 7 props (gate, tower, stack, crane, chimney, pit, grandstand).

PROVENANCE “honest keep/replace” table **explicitly celebrates procedural mass** — that is the opposite of captain doctrine.

---

## 4. Renderer quality inventory (AAA levers)

Reference: Forza Motorsport / GTA 5 cinematic full-3D; WebGL “push the boundary” column uses threejs-aaa-graphics-builder render recipes + realistic browser ceilings.

| Lever | Current state (measured/code) | Forza / GTA 5 class | WebGL close-gap (aggressive) |
|-------|-------------------------------|---------------------|------------------------------|
| **DPR / res** | `dpr={[1,1.75]}`; session canvas 1920×1080 @ dpr1 | Native display res | Full `min(dpr,2)` + quality tiers; optional 1.5× supersample |
| **Antialiasing** | WebGL MSAA on (`antialias: true`, samples=4) | TAA / high MSAA | MSAA + SMAA/TAA pass on high preset |
| **Color space** | Partial sRGB on textures; no explicit `outputColorSpace` in Scene | Full sRGB pipeline | Force `gl.outputColorSpace = SRGBColorSpace` on canvas |
| **Tone mapping** | **Not set** (Three default / unconfigured cinematic ACES) | Filmic ACES + exposure | `ACESFilmicToneMapping` + exposure tuning; HDR-ish emissive discipline |
| **Shadows** | **Circuit: no shadows** (comment: “Shadow maps double draw-call counts; Tier A uses unshadowed key + rim”). Arena-only castShadow. Ship meshes `castShadow=false`. | Cascaded shadows, contact, soft | Directional CSM or single 2048–4096 map on track corridor; contact shadows under craft; enable cast on hero/props |
| **IBL / env** | Poly Haven night HDRI, **reflections only** (`background={false}`), intensity from theme | Full IBL + sky/probe blend | Keep IBL; raise intensity balance; optional blurred sky dome with high-res generated sky (not only stars) |
| **Key lighting** | ambient + hemi + 2–3 directionals, **unshadowed** | Multi-light + baked/dynamic hybrid | Keep stack; add shadowed key; light cookies/gobos for neon |
| **Post chain** | **Bloom only** (`EffectComposer` + `Bloom` mipmapBlur) | Bloom + AO + motion blur + color grade + AA | Add N8AO/SSAO, mild motion blur or speed-aware trails, vignette, color grade; keep bloom for neon only |
| **Materials** | `MeshStandard` kit + ship GLB PBR; many untextured emissive primitives | Layered PBR, clearcoat, dirt, decals | Ship: preserve Tripo ORM/normal; props: clearcoat; stop flat emissive boxes for pickups |
| **Texture res** | Ships 1k; asphalt/metal **2K** CC0; HDRI 2k | Hero 2–4k; world 1–2k streaming | Near ship 2k; pads generated 1–2k; avoid 4k everywhere for VRAM |
| **Triangle budget (live)** | **~40–110k tris** mid race; draw ~40–135 | Millions on console/PC with LODs | Target 300k–1M with instancing + real LODs still feasible in WebGL on desktop |
| **Texture memory (live)** | ~156–238 MB reported | Higher with streaming | Budget OK headroom for 2k heroes |
| **Fog / depth** | Strong fog corridor | Atmospheric, layered | Keep readability; add midground prop density so fog isn’t hiding emptiness |

Code anchors: `src/game/Scene.tsx` (lights, fog, Bloom, Canvas dpr); `evidence/Scene-renderer-excerpt.txt`.

**Live budget example (spawn):** draw 130–136, tris ~95–109k, tex ~156 MB, fps ~120 — performance headroom exists; **visuals are quality-starved, not GPU-starved.**

---

## 5. Findings ranked by visual impact at 1080p

| Rank | Finding | Impact at 1080p | Evidence |
|------|---------|-----------------|----------|
| **P0** | **Majority of world is primitives** (buildings, pylons, pads, tunnel rings) — Amiga skyline | Entire vista | `foundry-drive-3.png`, `neon-razor-mid3.png`, PROVENANCE keep table |
| **P0** | **Pickup/boost/recharge = non-generated primitives** | Floor readability every few seconds | code + boost stills; pickup mesh source |
| **P0** | **AI field = boxes** | Race mode pack looks broken | race GIF/stills + `farOnly` |
| **P1** | **Hero ships faceted** (Tripo + 1k + i8 normals + non-uniform scale) | Chase-cam identity | race-ai-mid, ship spawns, GLB stats |
| **P1** | **No circuit shadows + bloom-only post** | Flat lighting, no contact grounding | Scene.tsx; all outdoor stills lack craft shadow |
| **P1** | **DPR cap 1.75** | Soft image on Retina/4K | Scene.tsx |
| **P2** | **Weapon VFX primitives** | Arcade juice but toy-like | WeaponVfx.tsx |
| **P2** | **Far LOD box pop** for player | Pop-in during long cameras | craftMeshes Detailed |
| **P2** | **Sparse real Tripo props** (7) vs dense procedural filler | “One nice gate, cardboard city” | PROVENANCE ledger |
| **P3** | Meshopt not “corrupting” topology | Secondary | glb-stats |

---

## 6. Category capture index (1080p evidence)

### Ships — ship select closeups
`screenshots/ship-select-agile.png` … `ship-select-bulwark.png` (8 files)

### Ships — in-race / spawn (Neon)
`screenshots/neon-ship-agile-spawn.png` … `neon-ship-bulwark-spawn.png`  
Also: `neon-start-1080.png`, `neon-razor-driving.png`, `neon-razor-mid*.png`

### Race AI (box silhouettes)
`screenshots/race-ai-spawn.png`, `race-ai-field-spawn.png`, `race-ai-mid.png`, `race-ai-opponents-close.png`  
`gifs/race-ai-box-silhouettes.gif`

### Boost / floor treatments
`screenshots/neon-boost-pad-close.png`, `neon-razor-mid5.png`, `neon-recharge-boost-area.png`

### Foundry
`screenshots/foundry-spawn-bulwark.png`, `foundry-drive-1.png` … `foundry-drive-5.png`  
Tunnel boxes: **`foundry-drive-3.png`**

### Environment vistas
Neon: `neon-razor-mid3.png`, `neon-driving-w-held.png`  
Foundry: `foundry-drive-*.png`

### UI
`screenshots/ui-mode-select.png`, `ui-ship-select.png`, `ui-title-2.png`

### Motion
`gifs/neon-drive-polygate-probe.gif`, `gifs/neon-drive-polygate-probe.mp4`

### Prior crew screenshots (not 1080p desktop)
`screenshots/prior-docs/*` — phone-shaped captures; **do not treat as 1080p proof**.

**Gap honesty:**  
- Pickup **closeup stills** of octahedron crystals were attempted via teleport (`neon-pickup-pads-*.png`) but camera/pose made pads less obvious than code proof; **code + PROVENANCE is definitive** that pickups are procedural.  
- Individual weapon projectile GIFs not fully isolated (need inventory grant); **WeaponVfx.tsx is definitive** that all FX are primitives.  
- Side-by-side **rendered** raw-vs-opt GLB viewer not run; **attribute/texture inspect is definitive** for quantize/1k impact.

---

## 7. One-page root cause: why it looks Amiga, not Forza/GTA 5

**Distance from the bar is not “one bad texture.” It is a full stack decision to ship a Tier-A budget prototype art direction while claiming AAA.**

1. **Doctrine mismatch.** Captain requires *every* visible surface to be generated 3D. The repo’s PROVENANCE and env kit **intentionally** keep pylons, buildings, pads, grids, surface markings, and far ships as **Three.js primitives**. Forza/GTA fill every meter with authored/generated solid assets; k-zero fills meters with emissive boxes and cylinders. Foundry’s tunnel is literally floating blue rectangles (`foundry-drive-3.png`) — that single frame is the Amiga thesis.

2. **Hero ships are the only near-field “real” models — and they are still soft AI meshes.** Eight Tripo GLBs (~16k tris, 1k textures, meshopt i8 normals) read as faceted plastic under a chase cam. Forza cars are authored hard-surface with multi-LOD and 2–4k materials. Meshopt did **not** explode topology; it **downscaled** the already-thin AI detail (4k→1k, float→quantized). Raw 4k sources still exist for five ships and prove quality was left on disk.

3. **Race mode self-sabotages the fantasy.** Seven AI craft are **hard-coded boxes** (`farOnly`). No Forza grid full of cubes would pass any review. This is likely the loudest “polygating” report when multiple craft share the screen.

4. **Renderer is intentionally thin.** No circuit shadows, no AO, no motion blur, no filmic tone map, bloom-only post, DPR capped at 1.75. Lighting is unshadowed key+rim so nothing contacts the asphalt. GTA/Forza sell depth with contact shadows, AO, and dense materials; k-zero sells neon bloom over flat primitives — which *amplifies* the toy look.

5. **Performance budget is not the bottleneck.** Live ~100k tris and ~156 MB textures at 120 fps means the project chose **budget art**, not **maxed WebGL**. Closing toward Forza-class browser is feasible: denser generated LODs, 2k heroes, real AI meshes, shadowed corridor, AO+grade, full DPR — without leaving the browser.

**Bottom line:** Prior crew “AAA” claims are **unsupported**. The ground truth is a cyberpunk **vertical-slice prototype** with a thin strip of Tripo hero/prop assets floating in a **procedural primitive world**, under a **minimal post stack**, with **opponent silhouettes that are boxes**. That combination cannot read as Forza/GTA at 1080p/4K until the violation inventory is cleared and the renderer levers are raised to the WebGL ceiling.

---

## 8. Recommendations (for the AAA overhaul plan — not implemented here)

1. **Violation purge:** replace pickups, boost pads, recharge, start grid, pylons, buildings, tunnel rings, billboard frames with **Tripo (or equivalent) generated GLBs** + instancing; ban bare `boxGeometry` in player-visible paths.  
2. **AI + LODs:** give opponents the same ship GLB family; real mid/far generated LODs — delete `farOnly` boxes.  
3. **Ship quality:** reimport raw 4k where available; soften/disable normal quantization; near-LOD 2k; fix non-uniform scale distortion in `craftLod`.  
4. **Renderer preset “Ultra”:** dpr≤2, ACES, corridor shadows, N8AO, bloom tuned, color grade; keep a “Tier A” fallback.  
5. **Weapons:** generated bolt/mine/seeker/rail meshes or high-quality mesh particles — not 6-segment cones.  
6. **Evidence gate:** no future “AAA” claim without 1920×1080 stills + live `renderer.info` + violation inventory count = 0.

---

## 9. Appendix — key file:line anchors

| Topic | Location |
|-------|----------|
| DPR + Bloom + unshadowed lights | `src/game/Scene.tsx` ~204–260, 281–286 |
| Player LOD Detailed + silhouette | `src/game/craft/craftMeshes.tsx` 207–310 |
| AI farOnly boxes | `src/game/craft/PlayerCraft.tsx` ~1256–1258 |
| Non-uniform GLB scale | `src/game/craft/craftLod.ts` 32–50 |
| Pickup primitives | `src/game/visuals/envKit.tsx` 444–508 |
| Boost primitives | `src/game/visuals/trackSurfaceLife.tsx` 25–120 |
| Weapon primitives | `src/game/weapons/WeaponVfx.tsx` ~600–830 |
| Meshopt optimize | `scripts/optimize-assets.mjs` ~88–90 |
| Provenance keep-procedural | `public/assets/PROVENANCE.md` 136–154 |

**Evidence index:** `evidence/file-index.txt`  
**GLB stats:** `evidence/glb-stats.csv`

---

*End of report. Scout complete — no code changes, no PR.*
