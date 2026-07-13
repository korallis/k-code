# Cross-review of draft x4 (`sr-p2-plan-x4/report.md`) — by planner C7

**Reviewed:** 2026-07-13, against `origin/main` @ `7103f67` and `sr-plan.md`. Every factual claim I rely on below was re-verified in the code during this review, not taken from either draft on trust.

## Verdict in one paragraph

x4 is a strong, honest draft. Its two opening defect claims are **both real** — I verified them in the code and my own draft missed both — and its insistence on replayable versioned truth (criteria snapshots, standalone gate reviews, decision-pinned effective-record state) is better than my draft in three specific places I concede below. Its main weaknesses are the mirror image: it spends P2 capacity re-architecting things the master plan explicitly froze (a `CONTRACT_VERSION` bump to remove `ofsted` in P2.0; replacing the active legacy commercial model; narrowing legacy chat ops), it serializes the whole phase behind a clinical/legal sign-off gate, it under-delivers §4b's "admin-editable" rate table (ops-publish only, no editor), and it omits the plan's CI bundle budgets entirely. The converged plan should take x4's evidence/replayability spine and defect fixes, and my draft's contract conservatism, transitional child-safety reason, §4b-faithful rate editor, concrete SQL/migration numbering, and parallel (non-serialized) sequencing.

---

## 1. Verification of x4's key factual claims

I checked every load-bearing claim x4 makes against the code. Results:

| x4 claim | Verdict | Evidence |
|---|---|---|
| P1 flat pricing over-counts 2:1 + nursing as 336 HCA + 168 RMN = 504h, violating the fixed-hours rule | **CONFIRMED — real defect, my draft missed it** | `computeFlatChargeOut` prices `workers × 168` HCA **plus** 168 RMN on top (`src/lib/workspace/flat-pricing.ts:92-116`). The repo's own established provision policy puts the nurse **inside** the ratio: "Nursing cover -> 1 DEFAULT_NURSE_ROLE (RMN) + remaining DEFAULT_CARE_ROLE" (`src/lib/commercial/provision.ts:218-222`, implementation `:310-324` — 2:1 + nursing = `1 RMN + 1 HCA`, totalConcurrent 2). §4b fixes 2:1 at 336 h/wk. P1's model prices a 2:1 nursing case at 3:1 total hours. The test enshrines the wrong expectation (`flat-pricing.test.ts`) |
| Fixture matrix uses stale keys (`staffingSignals.ratio`, `nursingCover`) that zod strips | **CONFIRMED** | `baseCqcExtract` passes `staffingSignals: { ratio: "1:1", wakingNights: true, nursingCover: false }` (`matrix.ts:82-86`); `staffingSignalsSchema` has `requestedRatio` and no `nursingCover` (`contracts/referral-extract.ts:131-145`); zod object schemas strip unknown keys. **Additional drift x4 didn't list:** `clinicalNeeds` in the same fixture passes `physicalHealth` and `behavioursOfConcern` (`matrix.ts:78-84`), neither of which exists on `clinicalNeedsSchema` (`referral-extract.ts:102-114`). Nuance: `fixtures-bridge.ts` repairs `ratio → requestedRatio` for workspace surfaces (`withFixtureOverrides`), so the pilot demo works — the degradation hits any test consuming the raw matrix |
| Extraction prompt actively classifies children as Ofsted | **CONFIRMED** | `src/lib/ingestion/prompt.ts:15`: 'use "ofsted" for children's placements (residential care, residential school, fostering, 16+ supported accommodation)'. **Additional catch:** line 10 describes Muve as "a UK provider of children's residential/fostering placements and adult supported living services" — the business framing itself is wrong under §4b and must change in the same PR |
| P1 moderated task study still outstanding | **CONFIRMED** | `docs/qa/runs/COORDINATOR-MERGE-2026-07-13-p1.md` "Open issues: None P0/P1. Human moderated task study (5–8 staff) is captain gate after PR, not this merge" |
| Upload is single-file (`upload-limits.ts:11-12`) | **CONFIRMED** | `UPLOAD_MAX_FILE_COUNT = 1`, comment "multi-doc envelope lands later" |
| My work queue is not service-line scoped | **CONFIRMED** | `src/app/workspace/[serviceLine]/page.tsx:35` calls `listWorkspaceQueue({ limit: 50 })` with no service-line argument — every `[serviceLine]` value shows the same global queue; bucket counts are also capped by the 50-row fetch |
| Legacy review action trusts a form-supplied reviewer name | **CONFIRMED** | `src/lib/referrals/actions.ts:21` — `reviewer` comes from `formData`, not the session |
| Legacy LA response contains Ofsted/children's-home boilerplate | **CONFIRMED** | `la-response.ts:47` branches on `home.regime === "ofsted" ? "Ofsted URN" : …`; the documents-to-follow line includes "Young Person's Guide" (`:79-81`) — children's-home paperwork |
| Chat ops can edit forbidden commercial fields | **CONFIRMED** | `contracts/chat.ts:16-27`: `set_property`, `set_target_margin`, `set_offered_fee`, `set_charge_override`, `set_other_weekly_cost`, `set_role_rate`, `set_weekly_hours` all exist |
| Criteria rows are mutable, so the `criteriaVersion` hash is not replayable | **CONFIRMED** | `scripts/db/seed-criteria.mjs:45-54` upserts rule text in place; my own draft logged this as risk R6 but proposed only an honesty chip — x4's snapshot is the stronger answer |
| Source route streams inline under broad `referral:read` with no media hardening | **CONFIRMED (severity: moderate)** | `source/route.ts:20` (guard), `:72-80` (streams stored contentType, `Content-Disposition: inline`). No byte-sniff, no CSP sandbox on the response. Upload restricts extensions, which bounds but does not eliminate the concern |
| "P0 explicitly lacked live migration execution" | **Plausible, not re-verified** | Consistent with the repo (no CI migration run exists); I did not re-read PR 22's history. The prescription (disposable-Neon rehearsal as a hard PR gate) is right either way and matches my draft's Neon-branch rehearsal |

**Bottom line of verification:** x4's evidence discipline is excellent. Nothing material in it is fabricated; two minor line-ref imprecisions only (`resolve.ts:74-91` vs `:74-89`; `criteria.ts:41-67` spans more than the ruleset schema). One small over-implication: the P2 milestone preamble refers to "the project's visual baseline sizes" — **no visual-regression baselines exist in the project today** (verified: no `toHaveScreenshot`, no snapshot dirs; the only mention is an aspirational comment at `matrix.ts:2`), so this is net-new work, which x4 elsewhere correctly places in the safe-now column.

---

## 2. Agreements (independent convergence — treat as settled for the converged plan)

Both drafts, independently:

1. **Same seven-item P2 scope** read from `sr-plan.md:55`, same cross-references to §2 rows, and the same "not P2" fence (work items/SLA/outbox/capacity/reporting/admin/cutover are P3+).
2. **Field verification = append-only rows + read-time effective record; extract never mutated.** Near-identical mutation contracts (action triple, typed corrected value, reason, actor, extract-version binding, content-minimised events).
3. **Amendments = versioned document sets + deliberate re-extraction + field-level deterministic diff + derived invalidation of decisions; no auto-merge on fingerprints; envelope *intake UX* stays out of P2** (x4 A-"Multi-document intake", my A1 — same resolution).
4. **Decisions = append-only with supersession; derived currency; nothing preselected ever; rationale required on divergence/no-advice; risk-class second person (distinct actor); visible version binding on the confirm surface; stable routes, no modal/gesture dismiss; dual-write legacy `human_review` as a compatibility projection; no-advice manual decision must be possible (both flag `recordHumanReview`'s non-null-recommendation guard as wrong for the workspace).**
5. **TDDI substance:** children in scope, evaluate fully, never routed to refer-on by age/regime; Ofsted corpus rules deactivated not deleted; solo compatibility re-scoped via criteria content with recorded rationale (no auto-pass, no gate deletion); all seven gates frozen; criteria stay `draft_unverified` until clinical sign-off; historical rows never rewritten.
6. **Flat pricing:** integer pence, hours × rate only, seeded HCA 3200p / RMN 6500p, versioned immutable rate cards, decisions bind a priced snapshot, forbidden-key leak tests so on-cost/absence/property/margin can never reappear in workspace DTOs.
7. **Safe-now vs study-informed split** with domain/backend first; UI merges behind flags with enablement as the study checkpoint; **BRB is not a proxy for the moderated study** (x4 states this explicitly; adopt the sentence verbatim).
8. **Screenshot-14 as a permanent regression extended to every new surface** (queue, panels, gates, decide, LA response, metrics exclusion), same assertion list.
9. **Migrations additive; append-only tables enforced by DB triggers (audit_log pattern); idempotent backfills; rollback = flags/dual-read, never destructive drops of human truth.**
10. **RBAC = static capability names now behind `can()`; policy engine stays pre-P5.**

This convergence is broad enough that the converged plan's skeleton is not in dispute — the argument is about five deltas, below.

---

## 3. Where x4 is right and my draft should yield (adopt from x4)

1. **The 2:1 nursing pricing defect (x4's single best catch).** Adopt in full: P2's commercial milestone must enforce Σ(role hours) = ratio total (168/336/504), with nursing consuming a post *inside* the ratio per the existing provision policy (`provision.ts:218-222`), and fix the P1 test that enshrines 504h for a 2:1. Keep x4's open question to the captain on whether nurse hours may split more granularly than one full post. My draft's §4.3/P2.3 must be amended accordingly.
2. **Fixture schema-drift repair + a parse guard.** Adopt: repair `ratio`/`nursingCover` (and the `clinicalNeeds` drift I found on top), and add x4's guard that fixture source objects reject unknown keys so drift cannot silently recur.
3. **Immutable criteria snapshot per evaluation run.** Adopt over my "currency chip only": persist the resolved ruleset (7 rules is tiny) keyed by the existing hash, so the gate review UI can honestly show "the rule used at the time". My R6 acknowledged the mutable-seed problem; x4 actually solves it. Consequence: my proposed optional `criteriaRuleId` on `gateResultSchema` becomes unnecessary — the snapshot can carry the gate→ruleId map server-side, keeping the shared contract untouched. I withdraw the contract-field proposal in favour of x4's sidecar.
4. **Standalone append-only `referral_gate_reviews`.** Adopt, reversing my rejected-alternatives entry. x4's design incidentally solves a real gap mine had: decision-form draft persistence is P3, so under my decision-embedded-only model a reviewer who resolves five gates and leaves loses the work. Durable per-gate review rows give resumability without touching P3's draft-persistence scope. The decision still snapshots the resolution set it consumed.
5. **Decision bindings must pin the effective-record state, not just `extract_version`.** Adopt: add a field-review watermark (or effective-record version) to the decision's binding block. My draft pinned extract/criteria/rate-card versions but left the overlay state implicit.
6. **Criticality registry: `placementRequest.regime` doesn't belong in it** (P1 `quality-panel.ts:43`), and presence ≠ provenance ≠ verification must be distinct signals in the quality panel. Adopt both framing and the removal.
7. **Service-line fail-closed guard on all P2 mutations** (`serviceLine === 'complex_care'`), given the route enum already exposes three lines while the queue isn't line-scoped. Adopt.
8. **Migration execution gates**: disposable-Neon apply as a hard PR gate; large backfills as separate idempotent scripts rather than inside the single-transaction migration file; readers-before-writers; PII-safe reconciliation counts. Adopt wholesale — operationally sharper than my "rehearse on a Neon branch" line.
9. **Visual screenshot baselines** (375/768/1440, light/dark, masked ids only): the master plan settled "visual regression from day one" (`sr-plan.md:15`) and neither P0 nor P1 delivered it; x4 restores it, my draft only added bundle budgets. Adopt both.
10. **Session-derived actor everywhere**, called out against the legacy form-supplied `reviewer` defect (`actions.ts:21`). My design already derived actors from the session but didn't name the legacy defect; adopt x4's explicitness.
11. **Source-route hardening scoped to the documents PR** (per-document authz by opaque id, media-type allowlist/disposition discipline) — adopt as part of my PR-P2.6 rather than as a separate security programme; full quarantine/sniffing pipeline stays with the intake row (later phase) unless the captain pulls it forward.
12. **`tddi_review_required` marker for pre-existing ofsted-tagged rows** (deliberate re-triage rather than silent relabel). Adopt alongside my forward-looking transitional reason — the two compose (existing rows get the marker; new child evaluations carry `tddi_criteria_draft` until sign-off).

---

## 4. Disagreements — where I hold my position, with rationale

**D1 — `CONTRACT_VERSION` bump / regime removal in P2.0 (x4) vs behavior repoint now + contract v2 later (mine). Hold mine.**
The master plan settles "additive-only backend during the rebuild (WS-0..5, WS-7 external shapes frozen)" (`sr-plan.md:15`) and *twice* positions contract v2 as **later** coordination (`:11` "a coordinated contract v2 later", `:32` "only via a later coordinated contract v2"). §4b orders the removal of Ofsted **machinery** — live routing, prompts, criteria, copy — not an immediate breaking change to the frozen enum. x4's own resolution concedes the blast radius ("update extraction, evaluation, criteria, audit projection, fixtures, and legacy UI in one coordinated PR") and its own migration table admits the rollback story is a forward-fix once real writes exist. Every acceptance test x4 writes for P2.0 ("no active runtime/corpus/test branch emits, requests, evaluates, or displays Ofsted") is satisfiable by the repoint: the prompt change kills *emits*, corpus retirement kills *evaluates*, the predicate deletion kills *routes*, and workspace UI has no Ofsted branches. What remains is a dormant enum literal and CHECK-constraint value — which is exactly the kind of vestige the plan's contract-v2 vehicle exists to clean up with `not_applicable` semantics at the same time. Converged plan: repoint in P2 (my PR-P2.4, expanded with x4's prompt-line-10 catch and `tddi_review_required` backfill), contract v2 stays a named later coordination.

**D2 — Replace the active legacy commercial model in P2 (x4) vs legacy-untouched + workspace-only flat model (mine). Hold mine, with two concessions.**
x4's argument ("forbidden fields would still affect stored totals, chat, responses, and audit") proves less than it claims: after P2, the numbers that *leave the building* — decision fee, LA response — exist only in the workspace flow, priced flat and snapshotted. The legacy working-plan panel, chat ops, and pipeline seed are legacy-surface internals scheduled for deletion at P4 cutover; rewriting them mid-rebuild is precisely the churn the plan's frozen-seams principle and its "two-UI drift" risk-register entry warn against, and x4's own "Explicitly not P2" list argues for the same discipline it then breaks. Concessions worth adopting: (a) a "superseded pricing model — not for LA pricing" banner on the legacy working-plan panel (one line, kills the misquoting risk x4 worries about); (b) once workspace decisions launch (my P2.7), stop applying `applyDeterministicCommercialOverlay`'s `rateVsCost` to *new* recommendation snapshots (`pipeline.ts:698-703`), so no fresh audit rows carry the retired cost model. Chat-op narrowing stays out of P2 (x4 itself hedges it to "a separate PR if it threatens the milestone"); x4's durable "working-plan v2 revisions" store is deferred behind the same study question both drafts share (does anyone need to price against something other than the effective record?) — derived pricing + decision snapshot is sufficient until that answer is yes.

**D3 — Evidence-model weight: source_sets + join rows + evidence heads + per-write optimistic versioning (x4) vs documents + extract_versions + latest-wins field reviews (mine). Hold the lighter model, adopt one concept.**
Append-only field reviews don't need per-write optimistic head versions: concurrent verifications of *different* fields should both succeed (x4's head serialization makes one fail for no user benefit), and concurrent corrections of the *same* field are visible in history with latest-wins — the safety requirement is that the **decision** pins what it confirmed, which D/adopt-5 (watermark) now guarantees. Presence indication is P3 (`sr-plan.md:56`). From x4's richer model I adopt the **candidate → review-diff → activate** amendment lifecycle (it matches "deliberate re-extraction" better than my immediately-active amendment docs), but implement it as a `status ('candidate','active','superseded')` column on `referral_documents` + `doc_set_version`, not three extra tables. Same behavior, half the schema.

**D4 — Rate table "admin-editable": ops-publish only until P4 (x4) vs minimal Settings editor now (mine). Hold mine.**
§4b rule 3 is captain-binding and says the rates live in an *admin-editable* table. An ops/migration publication path is not "admin-editable" for the Registered Manager; deferring the editor to P4 under the general "admin surfaces are P4" sequencing subordinates a binding rule to a roadmap default. The editor is ~one form on the existing Settings placeholder behind `rates:manage`, writing append-only versions. If the captain accepts ops-publish for the pilot, fine — but that's the captain's call to make, not a planning default (both drafts should surface it; mine does as A4).

**D5 — LA response `marked_sent` (mine) vs prepared/copied/downloaded only (x4). Weak hold; captain tiebreak.**
x4 reads "typed sent state" (`sr-plan.md:49`) as P3 operational truth; I read it as part of the LA-response screen spec that P2 delivers. The pragmatic argument for mine: staff *will* send responses by email during P2's lifetime, and without a `marked_sent` claim the system forgets the single most important fact about the referral for months. My version carries no SLA/work-item semantics — it is a typed human claim, superseded by P3's outbox. But x4's phase-purity argument is legitimate; this is a genuine judgment call the converged plan should put to the captain (default: include `marked_sent` as an append-only claim).

**D6 — Sequencing: serialize behind P2.0 TDDI/clinical sign-off (x4) vs parallel tracks (mine). Hold mine.**
x4 makes TDDI the first milestone and gates it on "clinical/legal confirmation before merge". Field-review, rate-card, documents, and decision *data cores* have no dependency on TDDI semantics; serializing the phase behind an external sign-off risks stalling everything on the slowest stakeholder. Converged: TDDI discovery starts day 1 in parallel; the repoint PR lands when its rule text is reviewed; nothing else waits. My transitional `tddi_criteria_draft` reason keeps children referrals safely in human review across the gap — x4 has no equivalent bridging mechanism, which is *why* it has to serialize.

**D7 — Disposition skeleton: derived read-only handoff only (x4) vs table + minimal record action (mine). Mostly concede to x4.**
On re-reading the roadmap, "outcomes/handover" is unambiguously P3 (`sr-plan.md:56`), and recording an outcome *is* outcomes. x4's narrower reading — a derived `not_recorded` handoff state with stable ids, no mutation — is more faithful to the phase split than my table + "Record LA outcome" action. Converged: adopt x4's reading; my migration `0016` and PR-P2.10 fold away (the disposition *contract* + derived state ride the LA-response PR). I keep one caveat: if the captain wants outcome capture earlier for win/loss data, it is a one-migration add-back — note it as an option, don't build it.

---

## 5. Errors / ungrounded or self-inconsistent elements in x4

None fatal; four worth flagging for the convergence:

1. **Internal tension with its own scope fence.** §"Explicitly not P2" (correctly) fences off operational/legacy churn, but §4.4 and the executive summary then pull in active-model replacement, chat narrowing, and legacy UI copy/badge changes with BRB on legacy routes (P2.0). The fence is right; the exceptions mostly aren't (D1/D2).
2. **Contract-freeze contradiction.** P2.0's `CONTRACT_VERSION` bump contradicts the settled frozen-shapes decision (`sr-plan.md:15`) and the plan's own "later" placement of contract v2 (`:11`, `:32`) — the one place x4 argues *against* its stated source-precedence rule ("the master plan wins").
3. **"The project's visual baseline sizes"** implies an existing visual-regression harness; none exists (only the aspirational comment at `matrix.ts:2`). Minor, since x4 elsewhere treats the harness as new work.
4. **Omissions vs the plan:** no CI bundle budgets (`sr-plan.md:39`; the P1 exit gate says "budgets met" and nothing enforces it — my draft adds the check); no concrete migration SQL or numbering against the repo's two-directory runner (acknowledged as "illustrative", but the converged plan needs the real thing); TDDI is left entirely undefined where a testable hypothesis (CQC regulated activity "Treatment of Disease, Disorder or Injury") would give the discovery a concrete starting point.

And, for symmetry, **errors in my draft that x4 exposed** (already conceded in §3, listed here so the convergence doesn't lose them): missed the 2:1 nursing over-count entirely (and my §4.3 implicitly perpetuated it); missed the fixture schema drift; missed `prompt.ts:15` as the live children→Ofsted classifier; kept `placementRequest.regime` in the criticality seed; decision bindings lacked an effective-record pin; proposed a contract-field (`criteriaRuleId`) where a server-side snapshot is cleaner; put outcome mutation in P2 against the roadmap's P3 placement.

---

## 6. What the converged plan should take from each draft

**Spine and sequencing — from C7 (mine):**
- Behavior repoint for §4b rule 1 (no contract bump); contract v2 stays later (D1).
- Parallel-track sequencing with the transitional `tddi_criteria_draft` reason instead of a phase-blocking P2.0 (D6).
- Legacy commercial machinery untouched except the superseded-banner + stop-new-overlay concessions (D2).
- Concrete migration files/numbering bound to the actual two-directory runner (`scripts/db/migrate.mjs:28-40`), with SQL sketches; lighter evidence schema (documents + status + extract_versions + `referrals.extract_version`) (D3).
- Settings rate editor behind `rates:manage` (D4, captain may waive).
- CI bundle budgets (catch-up on `sr-plan.md:39`); dual-write mechanics scoped precisely to `recordHumanReview`'s guards with the documented legacy-gap; risk-class computation mapped to existing signals; ambiguity log A1–A8 as the converged plan's decision record.

**Truth architecture and defect fixes — from x4:**
- Fixed-hours invariant Σ(role hours) = ratio total with nurse-inside-ratio; fix P1 flat-pricing + its test (their top catch).
- Fixture repair + unknown-key parse guard (plus my extra `clinicalNeeds` drift finding).
- Immutable criteria snapshot per evaluation (replaces both my currency-chip-only answer and my contract-field proposal).
- Standalone append-only `referral_gate_reviews` for resumable gate resolution.
- Decision binding pins effective-record watermark.
- Candidate → diff → activate amendment lifecycle (implemented on the lighter schema).
- Criticality-registry rework (drop `regime`; presence/provenance/verification as distinct signals).
- Service-line fail-closed mutation guard; session-derived actors named against the legacy defect; migration execution gates (disposable Neon, separate backfill scripts, readers-first, reconciliation counts); visual screenshot baselines; source-route hardening inside the documents PR; "BRB is not the study" stated explicitly.

**Put to the captain (both drafts flag, neither can settle):**
1. Nurse-hours granularity within the fixed ratio total (x4's Q3 / the defect fix's follow-on).
2. `marked_sent` in P2 vs P3 (D5).
3. Rate editor UI now vs ops-publish until P4 (D4).
4. Second-approval enforcement posture for a small pilot cohort (both drafts, same recommendation).
5. The refused-work list defining "genuinely out-of-scope" (both drafts, same recommendation).

**Net milestone effect on my draft if converged as above:** P2.1 unchanged; P2.2 adds registry rework; P2.3 absorbs the nursing-hours fix + invariant tests; P2.4 gains prompt line-10 + `tddi_review_required` backfill + criteria snapshots; P2.5 consumes snapshots + standalone gate reviews (new migration); P2.6 adopts candidate/activate + source hardening; P2.7 adds the effective-record watermark + legacy-panel banner + overlay stop; P2.9 absorbs the disposition derived-state; P2.10 is deleted. x4's fixture-repair lands first (it's a P0-debt fix, not new scope) — either as P2.0-lite or folded into P2.1.
