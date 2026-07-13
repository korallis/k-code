# Cross-review of P2 Draft C7 against Draft X4

**Reviewer:** sr-p2-plan-x4  
**Date:** 2026-07-13  
**Code baseline:** `origin/main` at `7103f67` (PR 24 merged)  
**Documents reviewed:**

- `/Users/leebarry/firstmate/data/sr-p2-plan-c7/report.md` — read end to end (512 lines);
- `/Users/leebarry/firstmate/data/sr-p2-plan-x4/report.md`;
- `/Users/leebarry/firstmate/data/sr-plan.md`;
- the disputed contracts, pricing, criteria, fixture, decision, migration, source-delivery, and P1 workspace code on latest `main`.

## Executive verdict

The drafts agree on the overall P2 architecture: immutable machine truth plus append-only human overlays; versioned amendments; human gate review; deterministic flat pricing; append-only decisions and approvals; decision-bound LA responses; additive Neon migrations; a safe-backend/study-informed-UI split; and permanent screenshot-14 coverage. C7 is particularly useful for concrete repository placement, capability vocabulary, SQL trigger expectations, migration rehearsals, and identifying ambiguity around intake, admin rates, solo compatibility, and refer-on.

The converged plan should not adopt C7 unchanged. It has three release-significant correctness defects:

1. It contradicts the binding “no Ofsted machinery” rule by retaining `ofsted` as a live accepted contract/database value, leaving the legacy Ofsted banner until cutover, and treating future Ofsted extraction as harmless (`C7:91-108,145,447,492-493`). Section 4b is later and explicitly binding: remove all Ofsted machinery/items from rebuild scope (`sr-plan.md:60-64`). Historical rows may remain immutable evidence, but there must be no live Ofsted input, criteria, routing, presentation, or decision path.
2. It says P1 already implements fixed ratio hours and should preserve `flat-pricing.ts` (`C7:17,111-113,137`). In fact a `2:1` nursing case is priced as 336 HCA hours plus 168 RMN hours—504 total—despite the binding 336-hour total (`src/lib/workspace/flat-pricing.ts:92-125`; `src/lib/workspace/__tests__/flat-pricing.test.ts:24-30`). This module and its test encode the bug and require replacement or correction, not preservation.
3. Its decision and amendment models do not bind or reproduce all truth required by the master plan. `referral_decisions` omits evidence/source-set, effective-record, gate-review, and working-plan revision ids, while staleness is derived only from `extract_version` (`C7:263-305`). A later field correction, gate resolution, criteria change, or plan edit can therefore leave a decision appearing current. That violates the explicit extract/evidence/criteria/plan binding and stale-diff requirement (`sr-plan.md:24-25`).

The best convergence is therefore C7's concrete implementation discipline applied to X4's stricter source/version graph, immutable criteria grounding, canonical commercial replacement, phase boundaries, and section-4b precedence.

## Agreements

### Scope and phase shape

Both drafts faithfully enumerate the seven P2 deliverables from `sr-plan.md:55`: field overlay/effective record, amendments, per-gate review, staffing/price decomposition, append-only neutral decisions, LA response preparation, and a disposition skeleton. Both keep work items, SLA policy, outbox delivery, capacity, presence, reporting, and cutover out of P2 (`sr-plan.md:56-58`).

Both correctly identify P2 as the point where the read-only P1 proof begins recording human truth. C7's inventory of P1 seams is useful (`C7:126-148`): keep the workspace shell, rank/keyset/narrow-DTO seams, feature/cohort flags, presenter safeguard, Clearline tokens, and the seven gate ids; extend or replace the evidence, quality, staffing, decision, source, and response interiors.

### Field reviews and effective records

There is strong agreement on:

- a dedicated append-only `referral_field_reviews` table;
- session-derived actor, reason, field path, action, and source/extract binding;
- never mutating `referrals.extract` as the historical machine artefact;
- one pure overlay function used by evidence, quality, staffing, readiness, decision, and response paths;
- keeping correction values and reasons out of logs/events;
- moving P1's hard-coded critical-field list into a service-line registry;
- deterministic, typed corrections rather than AI-written patches.

C7's proposed `effective-record.ts` API and content-minimised event shape (`C7:179-186`) are good implementation details. X4 adds necessary optimistic effective-record versioning and a requirement that the fully overlaid result reparse through `referralExtractSchema` (`X4:155-188,345-350`). The converged plan should include both.

### Amendments and source handling

Both drafts resolve the intake ambiguity similarly: P2 needs the backend document/source-set model and amendment flow, but does not automatically absorb the full first-contact intake redesign. Both require deliberate re-extraction, deterministic old/new field diff, explicit supersession/contradiction state, opaque document delivery, and preservation of prior truth if candidate extraction fails.

C7 correctly calls out that the WS-2 extraction funnel already accepts multiple documents and that the current source route resolves only one upload path (`C7:188-228`). X4's candidate-source-set activation and source-head design is the stronger persistence model; it ensures an amendment is reviewed before becoming effective and makes every historical set reproducible (`X4:157-178`).

### Decisions, approvals, and safety

Both drafts require:

- no preselected decision in any advisory state;
- a valid manual/no-advice path for failed or indeterminate evaluation;
- append-only decision revisions and supersession;
- server/session-derived actors;
- risk-class second approval by a distinct person;
- transaction-time stale checks and an inline old/new explanation path;
- content-minimised events plus durable, access-controlled rationale;
- response generation only from a confirmed human decision, never directly from the model recommendation;
- screenshot-14 to remain “No recommendation” throughout the workflow.

C7's separate append-only approvals table and derived current-decision projection (`C7:288-306`) are worth keeping. X4's complete binding tuple and explicit invalidation/revision records close gaps in C7's schema.

### Migrations and rollout

Both use additive migrations, dual-read/compatibility projections, cohort/subfeature flags, idempotent backfills, and no destructive rollback of human truth. Both correctly require migration rehearsal on a disposable Neon branch, a second idempotency run, append-only trigger checks, and reconciliation without logging clinical content.

C7 usefully distinguishes the `db/migrations/` lifecycle ledger from the `migrations/` criteria/audit ledger (`C7:152-158,249-251`). X4 adds the important operational sequence: readers before writers, synthetic cohort first, and forward-fix rather than destructive rollback after real human writes (`X4:287-311`).

### Testing and study split

Both drafts:

- extend P0's existing fixture matrix instead of creating a second fixture system;
- carry screenshot-14 through queue, detail, gate, decision, and response surfaces;
- cover contracts, repositories, transactions, routes, components, Playwright flows, accessibility, and DTO/free-text leak checks;
- require running-app BRB QA for every UI PR;
- distinguish the BRB release gate from the outstanding 5–8-person moderated P1 task study.

C7 adds a valuable missing budget-enforcement action (`C7:419-421`). X4 has the more complete state fixture matrix and visual/accessibility regression dimensions (`X4:393-446`). The converged plan should take both.

## Disagreements and recommended resolutions

### 1. TDDI and live Ofsted handling

**C7 position:** retain `regimeSchema = "cqc" | "ofsted"` and the database constraint; classify served children as CQC; stop using Ofsted for routing; retire Ofsted rules; allow any old model-emitted Ofsted value to evaluate; leave legacy Ofsted UI until cutover (`C7:91-109,145,447,492-493`).

**X4 position:** section 4b overrides the earlier dual-regime assumptions. First obtain a Clinical Lead/RM-authored TDDI regulatory/data ADR, then make one coordinated contract-v2 change across extraction, evaluation, criteria, persistence, fixtures, and both UIs. Remove Ofsted from every live path; retain historical raw/audit values only as history and mark affected cases for deliberate TDDI re-triage (`X4:35,55,79-85`).

**Recommendation:** adopt X4. C7's “harmless vestige” is still machinery and directly contradicts “remove all Ofsted machinery/items from the service-referral backlog and rebuild scope” (`sr-plan.md:62`). C7 also silently equates TDDI with CQC before the discovery the captain explicitly requested. The exact regulatory basis is not established by the local plan or code; it must not be encoded as an assumption.

Preserve one useful C7 safety idea: until approved TDDI criteria exist, an in-scope child case should carry a deterministic human-review blocker such as `tddi_criteria_unapproved`. Add it after the approved TDDI representation exists; do not use it to excuse an Ofsted-compatible live schema.

### 2. Commercial core: extend or replace

**C7 position:** preserve P1's `computeFlatChargeOut`, inject table rates, derive price from the effective referral, snapshot it on the decision, and leave legacy pay-cost/working-plan/chat machinery active only on the legacy UI (`C7:111-122,137,145,230-247,490-491`).

**X4 position:** replace the two active calculators with one flat commercial-v2 domain; role hours must sum to the ratio total; rate cards and working-plan revisions are immutable; no active DTO/form/chat/response may contain the forbidden legacy fields; legacy v1 JSON stays readable only for history (`X4:15,21,132-141,226-251,357-361`).

**Recommendation:** adopt X4's replacement, with C7's rate-version display and server-side reprice-at-confirm checks. C7 misses the current over-count and its proposal lacks the plan revision the master explicitly requires decisions to bind (`sr-plan.md:24-25`). A decision snapshot is not a substitute for a reviewable plan revision: staffing assumptions can change before confirmation and the stale path must identify which plan changed.

The converged commercial invariant should be:

- total HCA hours + total RMN hours = exactly 168, 336, or 504 for 1:1, 2:1, or 3:1;
- if nursing cover consumes one continuous RMN post, a 2:1 plan is 168 RMN + 168 HCA, not 336 HCA + 168 RMN;
- active roles are only HCA and RMN until the captain changes the binding rule;
- every plan revision binds the rate-card and formula versions;
- no hard-coded runtime fallback after Neon is configured; pricing is unavailable rather than silently calculated under an untracked rate.

Whether one full 168-hour RMN post is always the correct nursing mix still needs clinical confirmation. That is a business-rule question, not a reason to preserve the faulty P1 arithmetic.

### 3. Source sets, extract versions, and migration order

**C7 position:** place a `doc_set_version` integer on each document, add `referrals.extract_version` later in the amendments PR, and derive the active set from document rows and `superseded_by` (`C7:188-228`). Field reviews ship earlier and bind only an integer `extract_version` (`C7:160-184,431-436`).

**X4 position:** first create immutable document, source-set, source-set-membership, extract-version, and active-head records; backfill v1; then create field reviews against a real versioned head. An uploaded amendment creates a candidate set, and explicit activation advances the head (`X4:157-178,287-311,339-349`).

**Recommendation:** adopt X4's source-set graph and ordering. C7's `doc_set_version` is not an immutable set: it does not record the complete membership of version N, and later `superseded_by` updates make point-in-time reconstruction difficult. Its amendment POST also lacks an idempotency contract, so a retried upload can create duplicate Blobs/documents. Finally, C7 lands field-review UI before it introduces the canonical extract-version head those reviews claim to bind. The dependency order should be evidence versions first, field reviews second.

C7's deterministic `extract-diff.ts`, explicit re-extract endpoint, and amended-after-decision fixture should be retained.

### 4. Criteria replay and gate-review persistence

**C7 position:** add optional `criteriaRuleId` to `GateResult`, show current rules at render, compare their hash with `evaluation_runs.criteria_version`, and defer exact historical rule versioning until pre-P5. Store gate resolutions inside the eventual decision JSON, not as independent append-only review records (`C7:249-259,279,303,477,495`).

**X4 position:** preserve the frozen recommendation/gate contract, store a server-side immutable criteria snapshot/grounding sidecar for each evaluation, and store append-only human gate-review revisions independently; a decision binds the exact gate-review revision set (`X4:191-224,351-355,484-485`).

**Recommendation:** adopt X4. A “criteria changed” badge is honest but insufficient for replaying what a human saw and approved. P2 decisions must visibly bind criteria and gate state now, not after P5. Likewise, P2 explicitly contains a per-gate review UI; keeping all resolutions as unsaved client state until the final decision creates no durable human review trail, cannot support multi-session review, and makes amendment/criteria invalidation coarse. A separate append-only gate-review table does not prevent atomic decision confirmation—the confirm transaction can bind the current revision ids.

Use a grounding sidecar rather than adding `criteriaRuleId` to the shared `GateResult` in an otherwise “external shapes frozen” phase. If product genuinely wants rule id in the shared contract, coordinate it in the same explicit contract-version change as TDDI.

### 5. Decision binding, invalidation, risk policy, and compatibility

**C7 position:** bind extract, criteria hash, rate card, evaluation run, gate JSON, price snapshot, label, and fee; derive invalidation only when `decision.extract_version < referrals.extract_version`; dual-write `human_review` only when its legacy guard accepts; hard-code initial role grants and allow an environment off-switch for second approval in a single-reviewer pilot (`C7:263-306,338-351,460,473`).

**X4 position:** bind source set, extract, effective record, criteria snapshot, human gate-review revisions, immutable plan/rate/formula revision, provision, and commercial total; re-read all under transaction; keep the new table canonical and maintain a compatibility projection; require captain confirmation of capability grants and never bypass risk-class second approval (`X4:253-281,381-385,462-465`).

**Recommendation:** adopt X4's full tuple and C7's approvals/current-projection mechanics. C7's schema cannot detect a correction made after the decision because that does not bump `referrals.extract_version`; it cannot detect a changed gate review or plan because neither has a bound revision. The plan's stale-version requirement therefore cannot be met by its proposed comparison.

Do not adopt the approval environment bypass. The captain-set control says risk classes trigger second-person approval (`sr-plan.md:24`); an env toggle is a bypass with no plan basis and is inconsistent with C7's own rejection of admin bypass. If a pilot has only one authorised person, high-risk decisions remain awaiting approval or the cohort remains read-only.

Capability names should land now, but static role-to-capability grants—especially `clinical:decide`, second approval, rate management, and source download—need captain/security confirmation before production mutation. C7's table is a useful proposal, not a settled mapping.

For parallel UI truth, do not accept a documented state where the workspace says “human decision recorded” but legacy only shows `evaluation_failed`. Either update the compatibility reader/projection so both surfaces display the canonical human decision safely, or keep that case isolated to the workspace cohort with an explicit reconciliation invariant. Partial dual-write is not sufficient by itself.

### 6. Response and disposition boundary

**C7 position:** P2 stores mutable `sent_state`, including `marked_sent`, and ships a real “Record LA outcome” action with won/lost/withdrawn/no-response rows (`C7:48-49,60-61,308-336,439-440`).

**X4 position:** P2 stores immutable prepared response versions plus append-only prepared/copied/downloaded actions; it exposes a derived read-only `not_recorded` disposition seam. Sending, awaiting-LA state, outcome recording, owners, reasons, capacity release, and handover remain P3 (`X4:93-103,282-285,387-391`).

**Recommendation:** adopt X4's conservative boundary. The roadmap says P2 “LA response prep; disposition skeleton” and P3 owns operational truth and “outcomes/handover” (`sr-plan.md:55-56`). A mutable human `marked_sent` claim can diverge from the future outbox, and a real won/lost action is outcome recording rather than a skeleton. If the captain interprets the screen inventory's “typed sent state” as requiring P2 writes, resolve that explicitly; do not silently ship a second source of operational truth.

C7's deterministic decision-bound response builder is correct. Implement response bodies as immutable versions and state transitions as append-only action rows, not mutable columns on the body record.

### 7. P1 task-study gating

**C7 position:** build study-sensitive UI with stated defaults behind the cohort flag if the study slips, then fold findings into follow-ups (`C7:355-380,432,466`).

**X4 position:** safe backend/domain work starts immediately, but material interaction design and cohort expansion wait for completed study findings and captain acceptance (`X4:24,313-325,363-385`).

**Recommendation:** adopt X4. The moderated study is the explicit P1 exit condition (`sr-plan.md:54`), not optional polish. It is reasonable to prototype hidden UI against fixtures, but a UI PR should not be accepted/enabled as the P2 interaction answer until it records how the study changed or validated default tab behavior, evidence navigation, field actions, gate-review density, mobile routes, and decision flow. BRB remains an additional running-app quality gate, not a substitute.

### 8. Rate administration timing

**C7 position:** ship a minimal Settings rate editor in P2 because section 4b says the table is admin-editable (`C7:66-67,230-247`).

**X4 position:** ship immutable/versioned tables and an authorised repository/publication path in P2; P4 owns the UI (`X4:105-110`).

**Recommendation:** keep this as an explicit captain decision. The binding rule unquestionably requires editable data, but the roadmap unquestionably places admin surfaces in P4. The conservative default is X4's P2 table/repository plus controlled publication procedure, with no hard-coded runtime rates. If “admin-editable” means app UI now, take C7's minimal Settings editor as its own BRB-gated PR and have P4 absorb it later.

## Refutable errors or ungrounded claims in C7

| C7 claim | Evidence | Correction for the converged plan |
|---|---|---|
| Fixed ratio hours are “already implemented” and current flat-pricing tests should keep passing (`C7:17,111-113,137`). | `computeFlatChargeOut` always adds `workers × 168` HCA hours, then adds another 168 RMN hours (`flat-pricing.ts:92-125`). The test expects `336*3200 + 168*6500` for 2:1 (`flat-pricing.test.ts:24-30`). | Treat this as a P1 defect. Role hours, not just the ratio lookup, must sum to the fixed total; replace the failing expectation. |
| Falling back to constants when the configured rate table is unreachable follows the criteria repository's philosophy (`C7:120`). | `src/lib/criteria/repository.ts:13-17` explicitly says a configured DB error propagates rather than silently falling back; bundled fallback is only for local dev/tests. | Fail closed for production price publication. A labelled dev/test fixture fallback may exist, but no persisted plan/decision may bind an unversioned fallback rate. |
| Ofsted corpus rows can be retired through `effective_to` by the current corpus/seed upsert (`C7:107,254-255`). | `CriteriaCorpusEntry` has no effective dates (`src/lib/criteria/corpus.ts:16-26`); `fromCorpus` does not filter them (`repository.ts:42-57`); `seed-criteria.mjs:41-64` neither inserts nor updates `effective_to`. | A coordinated criteria migration/repository/corpus change is required. More importantly, binding section 4b requires no live Ofsted corpus at all. Preserve old rows as history, not as active fallback content. |
| Old extractor output `regime:"ofsted"` becomes harmless and “just evaluates” after routing is removed (`C7:104-107,447`). | If Ofsted rules are actually retired, DB retrieval filters them out and `assertDecisionGateCoverage` throws for missing gates (`repository.ts:94-110,130-154`). If fallback rules remain, live Ofsted machinery still exists. | Remove Ofsted from live extraction and validate/re-triage legacy cases under the approved TDDI contract. Do not rely on an internally inconsistent transitional path. |
| `assertDecisionGateCoverage` will pass “with Ofsted retired” (`C7:388,447`). | Coverage is asserted for the requested regime. An accepted `ofsted` regime with no active Ofsted rules fails all seven gates; current bundled corpus ignores `effective_to`. | Test the approved TDDI/CQC successor contract, and reject/route legacy Ofsted values to explicit re-triage—not ordinary evaluation. |
| The decision schema visibly binds extract/evidence/criteria/plan versions (`C7:47,274-305,448`). | Proposed columns contain `extract_version`, `criteria_version`, `rate_card_version`, and evaluation id, but no source/evidence-set id, effective-record version, human gate-review revisions, or working-plan revision (`C7:263-285`). | Persist and transactionally revalidate the full binding tuple required by `sr-plan.md:24-25`. |
| `doc_set_version` on each document is a document-set model that makes future envelope intake additive (`C7:58,188-228`). | No source-set header or membership table records the complete membership/head of each version. `superseded_by` changes later, and the upload route has no idempotency input. | Add immutable source-set headers and membership rows, candidate/current heads, and amendment idempotency. |
| Field-review data/UI can land before extract-version storage (`C7:431-436`). | The field-review table requires `extract_version`, but `referrals.extract_version` and historical extract rows are not introduced until the later documents PR (`C7:160-220`). | Land source/extract versioning and v1 backfill first; then reviews bind a real head/version. |
| All data models are study-independent and can be built now (`C7:20,359-366`). | C7 itself leaves the TDDI contract, critical fields, rate roles/overrides, second-approval roles, multi-file intake, and disposition semantics open (`C7:458-466`). Several choices change schemas and readiness behavior. | Build only additive foundations whose semantics are settled. Keep disputed enums/grants/policies out until their owners decide. |
| The TDDI-to-CQC interpretation is grounded enough for an engine repoint (`C7:100-108`). | The master only says discovery must record the TDDI regulatory basis (`sr-plan.md:62`); the current code is dual-regime and contains no TDDI model. | Treat C7's expansion of the acronym and regulatory conclusion as an assumption requiring Clinical Lead/RM/legal confirmation, not implementation truth. |
| Existing P0 fixtures can simply be kept and extended (`C7:142,395-407`). | The matrix builder writes `staffingSignals.ratio` and `nursingCover` (`matrix.ts:83-87`), while the contract expects `requestedRatio` and has no `nursingCover` (`referral-extract.ts:131-145`). P1's fixture bridge contains a compatibility repair (`fixtures-bridge.ts:82-96`). | Repair the source fixture matrix and add a parse-survival/unknown-key guard before using it as P2 evidence/commercial truth. Preserve the screenshot-14 semantics, not stale object keys. |
| Keeping legacy commercial machinery active is compatible because it is “legacy-only” (`C7:29,122,145`). | The active working-plan/chat contracts contain rate overrides, on-cost, absence, property, other cost, offered fee, target margin, and charge override (`working-plan.ts:33-67,86-116`; `chat.ts:16-27`). Section 4b forbids those factors in pricing windows (`sr-plan.md:64`). | Keep historical rows readable, but remove forbidden fields from active forms, chat ops, derived totals, responses, and decision snapshots in every reachable product surface. |
| Initial role-capability grants and an approval env off-switch are implementation defaults (`C7:342-351,460`). | The plan settles capability names but not the exact grants (`sr-plan.md:34`), and it gives no bypass to risk-class approval (`sr-plan.md:24`). | Get captain/security sign-off on grants. Enforce distinct approval without an environment bypass. |
| A 3–5 week estimate is actionable (`C7:450`). | No measured throughput, dependency duration, study date, clinical review SLA, Neon migration rehearsal time, or BRB defect allowance supports it. Several “parallel” PRs share contracts/migrations. | Omit the estimate or present it only after dependency owners and lane capacity are known. Milestone acceptance, not speculative duration, should govern sequencing. |

## Elements the converged plan should adopt from each draft

### Adopt from C7

1. The explicit ambiguity log for amendment versus initial intake, solo compatibility timing, shift-view necessity, admin rates, refused-work taxonomy, and legacy compatibility.
2. Concrete module and route placement, especially a pure effective-record function, deterministic extract diff, separate decision approvals, content-minimised events, opaque per-document source delivery, and a decision-bound response builder.
3. SQL-level append-only trigger expectations, dual migration-ledger awareness, idempotent backfill pattern, and disposable-Neon rehearsal twice before merge.
4. A deterministic `tddi_criteria_unapproved` human-review blocker until signed rules exist—after the live contract is corrected.
5. CI bundle-budget enforcement, recursive DTO leak tests, and per-PR BRB records under `docs/qa/runs/`.
6. Decision-state projections for awaiting second approval and response not prepared, but not “response sent” until P3 owns that truth.
7. The useful open question about whether pricing can ever depart from the effective-record ratio; if yes, a constrained, versioned staffing assumption belongs in the working-plan revision, never in an ad hoc rate/cost override.

### Adopt from X4

1. Explicit source precedence: section 4b overrides earlier dual-regime/Ofsted text and active legacy behavior.
2. A clinically approved coordinated TDDI contract change with no live Ofsted path; immutable historical values are retained without pretending they are current truth.
3. The two discovered P1 debts as first-class acceptance criteria: nursing hours over-count and stale fixture keys.
4. Immutable source-set headers/memberships/heads, extract versions, candidate amendment activation, idempotency, and effective-record versions before field-review writes.
5. Immutable criteria snapshots and a gate-grounding sidecar per evaluation; append-only human gate reviews; no reliance on today's mutable criteria to explain yesterday's decision.
6. One canonical flat commercial-v2 engine with immutable rate cards and working-plan revisions, a strict HCA/RMN-only active model, and removal of every forbidden field from active DTOs/forms/chat/responses.
7. Full decision binding and transaction revalidation across source set, extract, effective record, criteria snapshot, gate reviews, plan, rate card, formula, provision, and total.
8. A strict P2/P3 boundary: prepared/copied/downloaded response actions and a read-only `not_recorded` disposition seam only.
9. Study findings as a prerequisite for accepting/enabling material interaction design, with BRB as an additional UI quality gate.
10. The broader fixture/conflict matrix, screenshot baselines at mobile/tablet/desktop in both themes, keyboard/SR/400%/slow-network checks, and P1 source-finding regressions on every P2 UI PR.
11. Recognition that P1 My Work is role-labelled but currently consumes the same global queue and is not service-line scoped; do not let P2 mutation routes inherit that looseness.

## Recommended converged milestone order

1. **TDDI ADR + coordinated live Ofsted removal + fixture repair.** This is not study-dependent, but clinical/legal approval is required. Preserve historical rows and create explicit TDDI re-triage markers.
2. **Evidence/source/extract version foundation.** Immutable source sets/memberships/heads, opaque source ids, v1 backfill, idempotent amendment candidates, disposable-Neon rehearsal.
3. **Effective-record and field-review domain.** Append-only typed reviews, optimistic effective-record version, criticality/materiality registry scaffold, compatibility projection; no final UI.
4. **Immutable criteria grounding and gate-review domain.** Exact snapshots/sidecars, append-only human gate reviews, seven-gate readiness; approved solo compatibility criterion.
5. **Canonical commercial-v2 foundation.** Correct total-hours arithmetic, HCA/RMN rate cards, immutable plan revisions, active legacy-field/chat cleanup. Resolve the RMN role-mix and admin-editor timing questions before enablement.
6. **Study-informed evidence/amendment UI.** Apply the P1 study findings explicitly; run BRB on the running app and accessibility/visual matrix.
7. **Study-informed per-gate UI.** Distinguish machine score, exact rule/status, evidence, and human assessment; screenshot-14 remains unresolved/manual.
8. **Staffing/price UI.** Role-hours decomposition and formula expansion from a bound plan revision; no forbidden lines at any viewport.
9. **Neutral append-only decisions and second approval.** Complete bindings, distinct actor, no bypass, compatibility reconciliation, stale diff/re-review.
10. **Decision-bound response preparation and disposition seam.** Immutable response versions and append-only prepare/copy/download actions; read-only `not_recorded`; no send/outcome/handover mutation.

Every UI milestone requires a BRB real-user QA pass on the running app with no open P0/P1 and must record how the moderated P1 study informed or validated the interaction. Every migration milestone requires an idempotent backfill and rollback-by-flag drill on disposable Neon. The screenshot-14 fixture remains a cross-surface permanent regression in every milestone.

## Bottom line

C7 contributes useful specificity and several good implementation mechanisms, but its transitional Ofsted approach, commercial arithmetic assumption, criteria replay deferral, incomplete decision bindings, amendment schema, and P2/P3 boundary are not safe to converge as written. The final plan should use X4's truth/version model and binding-rule interpretation, enriched with C7's concrete SQL/module placement, approval projection, ambiguity catalogue, budget enforcement, and Neon/BRB checklists.
