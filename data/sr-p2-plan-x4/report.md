# Service-referral P2 implementation plan — “Human truth”

**Scout:** sr-p2-plan-x4  
**Prepared:** 2026-07-13  
**Code baseline:** `origin/main` at `7103f67` (`feat(workspace): add referral operations pilot workspace (#24)`)  
**Deliverable type:** planning only; no product code was written

## Executive recommendation

P2 should turn P1’s read-only proof into durable, replayable human truth without importing P3 operational state. Build it as an additive, flag-gated sequence of small PRs:

1. establish versioned source/extract/effective-record storage;
2. make field verification append-only and typed;
3. persist the exact criteria/rule grounding needed for human gate review;
4. replace both commercial calculators with one rate-table-backed flat charge-out model;
5. only after the P1 moderated study, add the field-review, amendment, gate-review, staffing, decision, and response interactions;
6. keep `referrals.human_review` and `referrals.extract` as compatibility projections until the P4 cutover, while the new P2 tables are the historical truth.

There are two immediate defects/debts to fold into the first P2 increments:

- P1’s nursing price prototype violates the captain’s fixed-hours rule. A `2:1` nursing case is currently tested as `336 HCA hours + 168 RMN hours`, i.e. 504 hours, even though `2:1` is bindingly 336 total hours (`src/lib/workspace/flat-pricing.ts:92-125`, `src/lib/workspace/__tests__/flat-pricing.test.ts:24-30`). The correct invariant is that HCA hours plus RMN hours equal the ratio total.
- The P0 fixture matrix uses stale keys (`staffingSignals.ratio` and `nursingCover`) which the tolerant Zod object strips; the canonical contract expects `requestedRatio` and has no `nursingCover` field (`src/lib/referrals/fixtures/matrix.ts:83-87`, `src/lib/contracts/referral-extract.ts:131-145`). P2 tests must repair the fixtures before treating them as commercial/evidence goldens.

The P1 technical BRB is green, but the human exit gate is not complete. The merged report says the 5–8-person moderated task study is still outstanding (`docs/qa/runs/COORDINATOR-MERGE-2026-07-13-p1.md:28-30`). Safe backend/domain work may start now; P2 interaction design and any cohort expansion must wait for the study findings and captain acceptance.

## Sources and precedence

I used these sources in this order:

1. The converged master plan, especially its settled decisions, P2 roadmap, and captain rules (`/Users/leebarry/firstmate/data/sr-plan.md`).
2. Latest `main` after P1 merged, not the pre-merge branch.
3. PR intent/review records for PRs 22, 23, and 24 via `gh-axi`.
4. The detailed F3/S8 screen and migration specifications referenced by the master plan. Where those older drafts disagree with the converged roadmap, the master plan wins.

The master plan’s section 4b is later and explicitly binding. It therefore overrides earlier text that still describes CQC/Ofsted as a dual regime or an Ofsted intake-exception lane. In particular, children are in scope under TDDI and must not be treated as Ofsted or “not ours” (`sr-plan.md:60-64`).

## 1. Exact P2 scope

The authoritative P2 line contains seven deliverables (`sr-plan.md:51-57`):

| P2 deliverable | Required outcome |
|---|---|
| Field verification overlay + effective record | Verify / Correct / Mark missing per canonical field; append-only actor/reason/version history; effective record is the immutable extract plus overlays applied at read time, never an in-place extract edit (`sr-plan.md:22-25`). |
| Amendments / supersession | Versioned document sets, source supersession/contradiction, field-level diff, deliberate re-extraction/re-evaluation, and invalidation when a material source changes (`sr-plan.md:37,55`). |
| Per-gate criteria review UI | Exactly the seven frozen gates; machine result, human assessment, evidence, exact rule/status/citation, and unresolved state are distinct. Solo compatibility is re-scoped through criteria with rationale, not deleted or auto-passed (`sr-plan.md:25,32,68-69`). |
| Staffing / price decomposition | Hours by role multiplied by the active flat charge-out rate, with formula expansion. Total ratio hours are fixed at 168/336/504 and the only rates are HCA £32/h and RMN £65/h. No on-cost, absence, property, other, margin, or override price lines (`sr-plan.md:63-64`). |
| Append-only decisions + neutral review/confirm | Nothing preselected; stable task routes; consequence-driven readiness; version binding; supersession; stale-version diff and re-review; risk-class second approval (`sr-plan.md:24-25,36,49`). |
| LA response preparation | Prepare, review, copy, and download a response derived from the confirmed decision snapshot. P2 does not send mail autonomously. |
| Disposition skeleton | Establish the handoff seam from confirmed decision and prepared response, but do not implement the P3 outcome/handover lifecycle. |

### Cross-cutting P2 requirements

These are not extra product features; they are prerequisites for implementing the seven deliverables correctly:

- **No Ofsted machinery.** Remove live Ofsted prompts, criteria, branches, badges, fixtures, copy, and service-line handling. Children remain actionable under the TDDI path, not the exceptions lane (`sr-plan.md:62`). Historical database/audit values may be retained as immutable evidence, but they must not remain a live decision path.
- **All seven gates remain.** `DECISION_GATES` stays unchanged (`src/lib/contracts/gates.ts:9-30`). The solo compatibility issue is solved by approved line-scoped criteria, not a contract deletion.
- **Static capabilities now.** Introduce `evidence:verify`, `clinical:decide`, `commercial:approve`, and `source:download` behind the existing `can()` seam; the scoped policy engine/admin UI remains P4 (`sr-plan.md:34,57`).
- **Accessible evidence is part of the review path.** The structured extract/transcript is the assistive-technology rendering for scans; keyboard, screen reader, 400% zoom, and 44px targets are acceptance criteria (`sr-plan.md:41`).
- **No recommendation remains a valid manual path.** A failed or indeterminate evaluation must allow evidence/gate review and a human decision without ever turning the stored schema stub into advice (`sr-plan.md:9-11`).
- **Special-category data stays out of URLs, logs, telemetry, client persistence, and event details.** Only ids, versions, codes, and derived signals belong in `referral_events`; correction/response free text belongs in access-controlled domain tables (`sr-plan.md:43`).
- **Flag-gated and additive.** The legacy surface remains available for rollback; P2 does not perform the P4 cutover (`sr-plan.md:15,21,57`).

### Explicitly not P2

Do not pull the following forward from the older S8 phase numbering. The converged master moved them later:

- work-item ownership, assignment events, SLA calendars/pauses;
- notification outbox and Cron sweep;
- capacity observations/commitments or Properties lens;
- LA outcome recording, capacity release, handover, and decided-without-outcome reports;
- private-worker acceleration, presence, or durable decision-form drafts;
- reporting/admin UI, capability policy engine, shadow cutover, redirects, and legacy deletion;
- supported-living or domiciliary activation.

Those belong to P3/P4/P5/P6 (`sr-plan.md:56-58`). P2 remains a complex-care slice. The permanent route enum already lists all three future lines (`src/lib/features/workspace.ts:12-18`), but P1’s queue query is not service-line scoped (`src/app/workspace/[serviceLine]/page.tsx:35-43`). P2 mutations must fail closed outside `complex_care`; future route names are not permission to activate future-line behavior.

## 2. Ambiguities and proposed resolutions

### TDDI representation versus the frozen `Regime` contract

The current shared schema is `"cqc" | "ofsted"` (`src/lib/contracts/common.ts:16-18`), criteria retrieval is keyed by it (`src/lib/contracts/criteria.ts:41-67`), and the extraction prompt explicitly classifies children as Ofsted (`src/lib/ingestion/prompt.ts:15`). That directly contradicts the binding rule.

**Resolution:** before enabling P2 UI, hold a short Clinical Lead / Registered Manager discovery to document what TDDI means in the data and criteria model. Recommended implementation is a coordinated contract v2 that makes regulatory basis explicit and removes `ofsted`; do not silently relabel old Ofsted values as CQC. Keep `ServiceLine` orthogonal. Update extraction, evaluation, criteria, audit projection, fixtures, and legacy UI in one coordinated PR with a `CONTRACT_VERSION` bump. Existing raw JSON/audit rows remain historical and are marked for TDDI re-triage/re-extraction rather than rewritten as if the original model had said something else.

This regulatory contract decision is not a P1 study question and should begin immediately, but it needs clinical/legal ownership before merge.

### Multi-document intake versus P2 amendments

The settled intake design is a multi-document envelope (`sr-plan.md:37`), while the P2 summary only names amendments. Current upload accepts exactly one file (`src/lib/ingestion/upload-limits.ts:11-12`) and stores it at one deterministic `/source` path (`src/app/api/v1/referrals/upload/route.ts:218-245`).

**Resolution:** P2 introduces the envelope/document-set backend because amendments cannot be correct without it, backfills current single-file referrals as source-set v1, and exposes an “Add amendment” flow that can contain multiple files. Keep the initial `/upload` stepper redesign out unless the captain explicitly places it in P2; it can use the same backend later. This avoids silently expanding P2 into a full intake rebuild while preserving the right domain model.

### LA “sent” state

The screen inventory mentions typed sent state (`sr-plan.md:49`), but P2 says response preparation and P3 owns operational truth/outcomes. The detailed synthesis also places response-sent in P3.

**Resolution:** P2 stores prepared response versions and audited copy/download actions only. It does not claim “sent”, pause/respond SLA clocks, or enter “awaiting LA”; those require P3 work items/SLA ownership.

### Disposition skeleton

The master does not define how much of disposition is a “skeleton”, while P3 explicitly owns outcomes/handover (`sr-plan.md:44,56`).

**Resolution:** in P2, derive a read-only `not_recorded` handoff state from the confirmed decision and latest response version and expose stable ids for the future P3 domain. Do not add outcome mutation, owner, loss reasons, capacity release, or handover tables yet. This is a real seam without duplicating P3.

### Admin-editable rates versus P4 admin surfaces

The binding rule requires rates in an admin-editable table (`sr-plan.md:64`), but admin UI is P4 (`sr-plan.md:49,57`).

**Resolution:** P2 adds immutable/versioned rate-card tables and a guarded repository, seeds HCA/RMN, and removes runtime constants. P4 adds the UI. Until then, an authorised migration/ops path can publish a new rate-card version; historical versions never mutate.

### Chat parity

The concise master P2 line does not name review chat, while the detailed S8 P2.4 specification does. Existing chat can edit forbidden commercial fields (`src/lib/contracts/chat.ts:16-27,36-84`).

**Resolution:** manual staffing editing is required in P2. Preserve chat only as parity work, and narrow its structured ops to the new staffing model; do not let chat change rate cards, hours outside the fixed ratio, property, margin, offered fee, or other costs. It can be a separate PR if it threatens the commercial-core milestone.

## 3. How P2 builds on P1

### Extend

| P1 seam | P2 treatment |
|---|---|
| Clearline tokens/primitives in `src/design/clearline/**` | Keep and extend through owned components. Do not restyle pages ad hoc. |
| Workspace shell and permanent `/workspace/[serviceLine]/**` namespace | Keep shell, server cohort gate, light/dark behavior, and mobile navigation. Add only task routes and context-specific navigation. |
| `src/app/workspace/[serviceLine]/referrals/[id]/page.tsx` | Decompose the 444-line read-only page into server read-model composition plus evidence/assessment/staffing client islands. Keep Overview/Evidence/Assessment/Staffing/Timeline vocabulary. |
| Queue rank, keyset cursor, narrow DTO, and “Why here” | Keep deterministic ranking. Extend only with content-minimised current human-decision/readiness signals; keep `extract`, sources, gates, chat, and plan forbidden in list DTOs (`src/lib/workspace/queue-dto.ts:25-38`). |
| `present-recommendation.ts` | Retain as the one advisory presentation safeguard; teach callers to prefer the append-only decision projection while retaining `human_review` compatibility. |
| `evaluation_runs` | Add effective-record/source-set/criteria-snapshot and gate-grounding references; preserve `completed | indeterminate | failed`. |
| Neon jobs/Cron/leases | Reuse durability. Add version ids to internal extract/evaluate payloads; do not replace the queue. |
| P0 fixture matrix | Repair schema drift, then extend it with P2 states rather than create a second fixture system. |

### Replace the P1 prototype interior

| Current module | Why replacement is required | Target |
|---|---|---|
| `workspace/_components/evidence-panes.tsx` | It is intentionally read-only and only lists six hard-coded fields; the action pane says P2 is pending (`:10-13,24-55,127-145`). | Interactive, accessible field task list backed by typed field DTOs, document ids, review state, and optimistic version. Preserve the three-pane shell only if the study validates it. |
| `workspace/quality-panel.ts` | “Evidence coverage” currently means a field is non-empty, not source-backed or human-verified; its critical list is hard-coded and includes `placementRequest.regime` (`:37-47,132-139`). | Service-line criticality registry + explicit source coverage, contradiction count, unresolved human gate tasks, and model self-report. Never conflate presence, provenance, and verification. |
| `workspace/flat-pricing.ts` | Hard-coded rates, prototype status, and the 2:1 nursing over-count. | One canonical commercial-v2 engine under `src/lib/commercial/`, backed by versioned Neon rates. The P1 file becomes a thin compatibility import or is removed. |
| `src/lib/commercial/pricing.ts`, working-plan v1 contracts/actions, and chat ops | Active model contains on-cost, absence, property, other, target margin, offered fee, charge override, and per-referral rate overrides (`src/lib/contracts/working-plan.ts:33-67`; `src/lib/commercial/pricing.ts:18-25`; `src/lib/referrals/working-plan-actions.ts:138-219`). | Versioned flat charge-out plan with role-hours only; immutable plan revisions; prohibited fields absent from active DTOs/forms/chat. Historical v1 JSON remains readable for audit only. |
| `src/lib/referrals/actions.ts` | It overwrites `human_review`, requires a non-null recommendation, trusts a form-supplied reviewer name, and only compares the plan version (`:15-49,68-93`). | Session-derived actor, append-only decision/revision/approval/invalidation records, complete version binding, manual no-advice path, and compatibility projection dual-write. |
| `src/lib/referrals/la-response.ts` | It drafts from model recommendation and a `Home`, includes Ofsted-specific language, and is not bound to a confirmed decision (`:24-79`). | Decision-snapshot response service with immutable response versions and tracked copy/download. |
| `/api/v1/referrals/[id]/source` | It resolves one path and streams arbitrary inline content under broad `referral:read` (`src/app/api/v1/referrals/[id]/source/route.ts:13-20,58-80`). | Opaque document-id route, per-document authorization/capability, safe media handling, no Blob token/path exposure, and accessible transcript/metadata DTO. Keep `/source` as a compatibility resolver only. |

### Leave untouched unless needed by an additive sidecar

- `DECISION_GATES` order and `RecommendationResult` decision semantics;
- AI Gateway wrappers/safety middleware and the “no bare provider call” rule;
- private Blob seam and EU/residency posture;
- append-only `audit_log` immutability and pino/Sentry redaction;
- P1 rank policy/keyset pagination;
- P0 session request memoization and upload size limits;
- Clearline brand/type/color tokens;
- P4 reporting/admin/cutover code paths.

## 4. Target P2 architecture and module plan

### 4.1 Source sets, extract versions, and amendments

Add server-only modules:

- `src/lib/evidence/contracts.ts` — opaque document/source-set/extract-version ids and safe DTO schemas;
- `src/lib/evidence/critical-fields.ts` — service-line criticality registry and materiality flags;
- `src/lib/evidence/effective-record.ts` — apply a reviewed overlay to a specific extract version, then validate the complete result with `referralExtractSchema`;
- `src/lib/db/referral-evidence.ts` — transactional source-set, extract-version, head, and field-review repository;
- `src/lib/referrals/amendments.ts` — candidate set creation, diff/materiality classification, activation/invalidation orchestration;
- `src/app/api/v1/referrals/[id]/documents/[documentId]/route.ts` — authorised source delivery by opaque id;
- `src/app/api/v1/referrals/[id]/amendments/route.ts` — idempotent amendment creation;
- `src/app/workspace/[serviceLine]/referrals/[id]/amendment/page.tsx` — study-informed add/review/activate route.

Required behavior:

- Uploading an amendment creates a candidate source-set version; it never appends silently to the active set.
- Per-file fingerprints create duplicate **candidates** only. They never auto-merge or reveal an out-of-scope referral.
- The extract worker evaluates the candidate set and writes a new immutable extract version. Failure leaves the current source/effective record and current decision history intact.
- A reviewer sees a field-level old/new/source diff and deliberately activates the new set/extract.
- Materiality comes from the critical-field registry, not an LLM. Activating a material change appends invalidation metadata for any pending approval/current response and requires re-review; it never deletes the old decision.
- Re-evaluation is a separate deliberate action against an exact effective-record version. The job payload and `evaluation_runs` row carry that version.
- Source supersession/contradiction state is explicit and replayable. A source is not “wrong” merely because it is older; historical decisions retain the exact set they used.

### 4.2 Field reviews and effective record

The mutation contract should accept:

- referral id;
- extract version id;
- expected effective-record version;
- allowlisted canonical field path;
- action: verified, corrected, or marked missing;
- typed replacement value only for corrected;
- source document/page/anchor reference;
- structured reason code and optional restricted note.

The actor id/role always comes from Neon Auth, never form data. In one transaction, lock the evidence head, reject a stale expected version, validate the field/value through the registry and final `ReferralExtract` schema, insert the append-only review row, and advance the head version. `referral_events` receives only action kind, field classification (not the field value), versions, and actor id/role if policy permits.

Read paths return a minimal field view model rather than serialising the full extract into a client coordinator. A field DTO contains label, typed display value, review state, source anchor ids, critical/material flags, and effective-record version. Corrections remain distinguishable from model extraction in every screen and export.

The criticality registry needs Clinical Lead sign-off. It must be line-scoped even though P2 activates only complex care, so later lines cannot inherit generic critical fields accidentally.

### 4.3 Evaluation grounding and human gate review

The current engine hashes the complete ruleset into `criteriaVersion` (`src/lib/evaluation/engine.ts:82-100`) but discards the model’s `ruleId` after resolving gates (`src/lib/evaluation/resolve.ts:74-91`), and the mutable criteria table cannot reconstruct an old hash by itself. P2 cannot honestly show “the rule used at the time” from the current records alone.

Add:

- `src/lib/evaluation/grounding.ts` — internal/server-only sidecar containing resolved gate → cited rule id(s), without widening `RecommendationResult`;
- an immutable criteria snapshot on each evaluation run, or a normalized `evaluation_criteria_snapshots` table keyed by the existing hash;
- `src/lib/gate-review/readiness.ts` — deterministic human-review task/readiness policy;
- `src/lib/db/gate-reviews.ts` — append-only human gate assessments with supersession/version conflict;
- `src/app/workspace/[serviceLine]/referrals/[id]/gates/page.tsx` — stable, study-informed gate task route.

For each of exactly seven gates, show four independent layers:

1. advisory status/rationale, or “not assessed/no advice”;
2. source evidence anchors;
3. criteria rule id, immutable text/citation, and `draft_unverified | approved` status;
4. human assessment and note/condition.

An advisory pass is not labelled human-approved. `not_assessed` cannot appear passed. Draft criteria stay visibly draft at the rule. Every critical/unassessed gate and material assumption needs explicit resolution for every decision, irrespective of model confidence. Verified non-critical passes do not need seven-click theatre.

The compatibility gate remains present. The complex-care solo-setting rule must state, with recorded approved rationale, why peer co-placement risk is absent while environment, staffing, tenancy, safeguarding, and community compatibility still need evidence. No code-level auto-pass.

### 4.4 Commercial v2

Create one canonical active model:

- `src/lib/commercial/charge-out/contracts.ts` — only `hca | rmn`, ratio, role-hours, rate-card version, formula version, line charges, total;
- `src/lib/commercial/charge-out/calculate.ts` — integer-pence pure function;
- `src/lib/commercial/charge-out/rates.ts` — server repository for the effective immutable rate card;
- `src/lib/db/charge-out-rates.ts` — Neon persistence/publication;
- `src/lib/db/working-plan-versions.ts` — immutable plan revisions plus current head;
- `src/app/workspace/[serviceLine]/referrals/[id]/staffing/page.tsx` — decomposed shift/role-hours and formula view;
- narrowed `src/lib/contracts/chat.ts`, `src/lib/commercial/ops.ts`, and review-chat prompt/service if chat parity remains in P2.

Hard invariants:

- `1:1 = 168`, `2:1 = 336`, `3:1 = 504` total role-hours per week.
- Sum of HCA and RMN role-hours equals the ratio total; nursing is not added above the ratio.
- Price equals `HCA hours × HCA rate + RMN hours × RMN rate`, integer pence.
- Active seed is HCA 3200 pence/hour and RMN 6500 pence/hour.
- Rate changes create a new rate-card version. A saved plan remains bound to the old version until a human deliberately reprices it.
- No active input, output, form, chat op, event, response, or DTO contains on-cost, absence, property, other cost, target margin, offered-fee comparison, charge override, or per-referral role-rate override.
- A decision binds an immutable working-plan revision, provision label, each role-hour/rate line, and total weekly charge.

Existing `referral_working_plans` is a mutable one-row head (`db/migrations/0005_referral_working_plans.sql:6-27`). P2 should add immutable v2 revisions and use the existing row only as a legacy/current projection. Do not rewrite stored v1 JSON in place; it may be needed to explain old decisions. The v2 UI must never render its forbidden lines.

### 4.5 Append-only decisions

Add:

- `src/lib/decisions/contracts.ts` — decision revision, bound snapshot, risk class, approval, invalidation DTOs;
- `src/lib/decisions/readiness.ts` — deterministic blockers/diff policy;
- `src/lib/db/referral-decisions.ts` — append-only decisions, approvals, invalidations, and current projection transaction;
- `src/lib/audit/decision-log.ts` — content-minimised audit event writer;
- stable routes `.../decision/page.tsx` and `.../decision/confirm/page.tsx`;
- server actions that require `clinical:decide`/second-approval capability and derive actor from session.

Readiness binds:

- active source-set and extract version;
- effective-record version;
- evaluation run (nullable for a valid manual/no-advice path);
- immutable criteria snapshot/hash;
- latest human gate-review revision set;
- immutable working-plan revision/rate-card/formula version;
- provision and weekly charge snapshot.

The review route starts with no human choice selected. Accept, accept-with-conditions, and decline have equal visual weight. If there is no trustworthy recommendation, show that fact as secondary context and require a human rationale; do not block solely because `recommendation` is null. This replaces the current `recordHumanReview` precondition (`src/lib/referrals/actions.ts:41-49`).

The confirm action re-reads all versions under transaction. A conflict returns a structured, authorised diff and routes the reviewer back to the affected evidence, gate, or plan task; it is not a generic toast. Confirmation appends a decision revision, approval state, audit row, and minimal event, then dual-writes `referrals.human_review` for the old UI.

Second-person approval is deterministic for decline, crisis, safety-signal, low-evidence, and policy-defined high risk (`sr-plan.md:24`). The second actor must be different and must see the same bound snapshot. No response is “ready” until required approval completes. Supersession/invalidation never updates or deletes prior decision history.

### 4.6 LA response and disposition seam

Add:

- `src/lib/responses/contracts.ts` and `template.ts` — deterministic decision-bound response generation;
- `src/lib/db/referral-responses.ts` — immutable response versions and append-only prepared/copied/downloaded actions;
- `src/app/workspace/[serviceLine]/referrals/[id]/response/page.tsx`;
- a server download route that reads an authorised persisted version and records download success without logging content;
- `src/lib/disposition/skeleton.ts` — derived `not_recorded` handoff using decision/response ids only.

A response is generated only from an effective confirmed decision (including second approval when required). It includes the bound provision, flat weekly charge, conditions, and numbered missing-information asks chosen by the human. It never derives the offer from the model’s current recommendation and never includes Ofsted/home boilerplate. Copy acknowledgement happens only after client clipboard success; downloads are generated server-side. The response body stays in the response table, never in events/logs/Sentry.

If any bound version becomes stale, the response remains historical but is labelled stale and cannot masquerade as the current prepared response. P2 stops at prepared/copied/downloaded and a read-only “outcome not recorded” handoff.

## 5. Neon data model and reversible migration plan

Use the next free migration numbers after rebasing; names below are illustrative. The repository applies each SQL file whole in its own transaction and requires `DATABASE_URL_UNPOOLED` (`scripts/db/migrate.mjs:1-39`). That makes DDL atomic, but it also means large production backfills should be a separate idempotent script/job, not a long all-or-nothing migration.

| Migration | Additive schema | Backfill / compatibility | Rollback strategy |
|---|---|---|---|
| `0011_referral_evidence_versions.sql` | `referral_documents`, `referral_source_sets`, join rows with source status, `referral_extract_versions`, `referral_evidence_heads`; unique `(referral_id, version)` and active-head indexes. | Idempotently create source-set/extract v1 from current `referrals.extract/sources`; keep `referrals.extract` as projection. | Disable P2 evidence subflag and readers; legacy projection remains. Do not delete activated versions. Empty tables can be dropped only in a tested emergency rollback before user writes. |
| `0012_referral_field_reviews.sql` | Append-only field reviews with action, typed value JSON, source anchor, actor, reason, extract id, effective-record version; optimistic head version. | No synthetic “verified” backfill. Existing fields start unreviewed. | Stop writes/read overlay; base extract still renders. Preserve human reviews as audit evidence. |
| `0013_evaluation_grounding.sql` | Criteria snapshot/grounding sidecar; nullable source-set/extract/effective-record refs on `evaluation_runs`; append-only `referral_gate_reviews`. | Existing runs retain hash and null snapshot; UI says historical rule snapshot unavailable rather than querying current rules as if exact. | Sidecar is optional to legacy evaluation readers. Never rewrite old `evaluation_runs`. |
| `0014_flat_charge_out.sql` | Immutable rate-card headers/lines; working-plan v2 revisions/current head; constraints for role, pence, versions, and total ratio hours. | Seed HCA/RMN. Snapshot the current plan as legacy-v1 metadata, but do not convert forbidden cost lines into v2 charge. Re-seed v2 deliberately. | Switch active reader back to v1 only while legacy UI remains; retain all v2 rows. Rate publication is append-only. |
| `0015_referral_decisions.sql` | Append-only decision revisions, approvals, invalidations, bound snapshot ids; indexes for current revision and pending approval. | Convert existing `human_review` to one `legacy_import` decision revision with known plan snapshot fields and explicit unknown version refs; keep JSON projection. | Disable P2 decision mutation and continue legacy projection. Never delete decisions. |
| `0016_referral_responses.sql` | Immutable response versions and content-minimised response action rows. | Do not import untracked client-side drafts as if sent/prepared. | Disable response route; preserve prepared artefacts. |
| Criteria/TDDI migration in `migrations/` | New regulatory-basis constraint/versioning required by the approved contract; deactivate live Ofsted rules without deleting audit evidence. | Mark affected active referrals `tddi_review_required` for deliberate re-triage/re-extraction. Do not silently map historical claims. | Runtime can return to old contract only while the cohort flag is off and before new TDDI writes; use a rehearsed forward-fix after real writes, not destructive rollback. |

### Migration execution gates

For every migration PR:

1. Test migration SQL shape and repository behavior in Vitest.
2. Apply to a disposable Neon database with production-like extensions/settings; P0 explicitly lacked live migration execution, so this is a P2 hard gate.
3. Run idempotent backfill twice and prove row counts/heads do not change on the second run.
4. Run reconciliation queries that compare current projection to new heads using ids/counts/hashes only—no referral content in telemetry.
5. Verify constraints, indexes, and query plans at expected volume.
6. Deploy readers before writers where dual-read is needed; then writers; then enable the P2 subflag for a synthetic cohort.
7. Keep old columns and routes through P4. “Reversible” means flags/dual-read can restore service without erasing new human/audit truth. Destructive down migrations are inappropriate after real reviews or decisions exist.

## 6. Safe-to-build-now core versus study-informed remainder

| Safe to build immediately behind disabled P2 subflags | Must consume P1 study findings before UI merge/enablement |
|---|---|
| Evidence/source/extract version tables and repositories. | Whether the three-pane layout, tab default, field ordering, and mobile task routes actually let staff find/verify evidence. |
| Typed effective-record overlay engine, optimistic version conflicts, minimal audit/event payloads. | Verification labels, correction flow, reason prompts, and how contradictions are presented. |
| Criteria snapshot/gate-grounding persistence and append-only gate-review repository. | Gate task language, density, progressive disclosure, and readiness blocker copy. |
| Flat commercial v2 pure function, immutable rate tables, plan-revision storage, removal of forbidden active fields/ops. | Shift/role-hours editor layout, formula expansion, and whether chat parity helps or distracts. |
| Capability vocabulary and route-guard tests, retaining conservative current behavior behind flags. | Final static role→capability grants for decision/second approval if the study exposes real role boundaries. |
| Fixture repair/expansion, migration tests, privacy/leak tests, screenshot harness. | State-aware default tab, decision review/correct/confirm navigation, mobile action placement, response workflow/copy. |
| TDDI regulatory discovery and contract proposal. | Any child/TDDI UI wording and criteria-review copy, after clinical sign-off. |

Do not use the BRB result as a proxy for the study. BRB is a release-quality real-user simulation and defect gate; the moderated study measures actual staff comprehension and task performance. If the study misses the 80% next-item or 30-second source target, fix P1 interaction/navigation first, then rebase P2 UI on that result. The backend foundations remain useful.

## 7. Single-PR milestones and acceptance criteria

Each UI milestone requires a BRB auto-QA pass on the running app, with mobile 375×812, tablet 768×1024, and desktop 1280×800 (plus the project’s visual baseline sizes), light/dark, keyboard, and screen-reader task coverage. A UI PR is not accepted with any open BRB P0/P1.

### P2.0 — TDDI contract and live Ofsted removal

**Scope:** approved regulatory-path ADR; coordinated contract bump; extraction prompt, evaluation branch, criteria corpus/repository, staffing comments, service-line helpers, legacy/new UI badges/copy/tests; complex-care child fixture; solo compatibility criteria rationale. Preserve historical data without a live Ofsted path.

**Acceptance:** no active runtime/corpus/test branch emits, requests, evaluates, or displays Ofsted; a child referral follows TDDI, remains in-scope, covers all seven gates, and never renders the refer-on control solely due to age; old affected rows are explicitly queued for TDDI review; criteria remain draft until RM/Clinical sign-off; full contract/evaluation/migration tests pass. Because visible legacy/workspace copy changes, run BRB on both flagged and legacy routes.

**Dependency:** clinical/legal confirmation of the TDDI data/criteria shape; not dependent on P1 study.

### P2.1 — Versioned evidence storage and migration

**Scope:** evidence migrations, server repositories, v1 backfill script, read projection, opaque document ids, source delivery authorization/security, fixture builders. No field mutation UI.

**Acceptance:** every migrated referral has exactly one reproducible v1 source set/extract version; second backfill run is a no-op; source access never exposes Blob paths/tokens; fixture and real-source routes are private/no-store; legacy detail still renders when the P2 subflag is off; live disposable-Neon migration and rollback-flag drill pass.

### P2.2 — Effective record and append-only field reviews

**Scope:** critical-field registry scaffold, typed overlay engine, field-review DB/action/route, optimistic conflict response, event/audit minimisation, effective-record DTO. No final pane UX.

**Acceptance:** Verify/Correct/Mark missing is append-only; extract JSON is byte-for-byte unchanged; invalid field paths/types fail closed; corrected effective record reparses through the canonical schema; two concurrent edits produce one success and one actionable version conflict; arbitrary correction values never enter logs/events; no synthetic verification backfill.

### P2.3 — Immutable criteria grounding and gate-review domain

**Scope:** criteria snapshots, gate-rule sidecar, evaluation-run version refs, gate-review repository, deterministic readiness policy, approved solo compatibility rule content after sign-off. No final gate page.

**Acceptance:** every new completed evaluation can replay exact rule text/id/status/citation; all seven gates have one human task state; advisory, human assessment, and criteria status are distinct; `not_assessed` never satisfies readiness without explicit resolution; indeterminate evaluation still permits manual gate review; old runs with no snapshot say unavailable; no `RecommendationResult` widening.

### P2.4 — Canonical flat commercial core

**Scope:** immutable rate tables, pure commercial-v2 engine, plan revisions, seed/reprice path, active-contract cleanup, forbidden chat-op removal, fixture corrections. Keep visible P1 tab read-only until the later UI PR if desired.

**Acceptance:** exhaustive 1:1/2:1/3:1 × HCA/RMN-mix tests; role hours always total 168/336/504; 2:1 one-RMN mix is 168 HCA + 168 RMN, not 504 hours; rates are read from the active card; a rate update creates a new version without changing old plan totals; recursive DTO/contract tests find none of the forbidden pricing keys; integer-pence arithmetic only; model/chat never calculates money.

### P2.5 — Study-informed evidence and amendment UI

**Scope:** extend/replace P1 evidence pane with field tasks, bidirectional field↔source focus, correction UI, completion/contradiction rail, candidate amendment upload/diff/activate, accessible transcript, state-aware default based on accepted study findings.

**Acceptance:** representative reviewer can find a critical source and complete Verify/Correct/Mark missing keyboard-only; mobile is a stable task route rather than a gesture-dismiss sheet; 400% reflow works; screen reader can complete the task on a scanned-source fixture via structured transcript; stale edit recovery preserves input; activating a material amendment marks dependent plan/gate/decision/response state stale without deleting history; failed re-extraction leaves the prior effective record active. BRB YES required.

### P2.6 — Study-informed gate review UI

**Scope:** Assessment/gates route, exact evidence/rule panel, human gate controls, condition/note handling, readiness progress, draft-rule warning, no-advice mode.

**Acceptance:** seven gates exactly; advisory pass never reads as human approval; exact criteria version/status is visible and accessible; critical/unassessed gates block decision until explicitly resolved; non-critical verified gates do not demand meaningless clicks; solo compatibility follows the approved criterion; screenshot-14 fixture shows no recommendation and seven unresolved human tasks, never a green Accept. BRB YES required.

### P2.7 — Staffing and price workspace

**Scope:** extend the P1 tab into role-hours/shift decomposition, source-backed ratio, formula expansion, optimistic plan-version recovery, optional narrowed chat parity.

**Acceptance:** every visible total expands to role hours × rate; no prohibited cost/margin/property line or debug copy appears at any viewport; rate-card version/status is visible; plan conflict shows an inline old/new diff; plan save is server-authoritative; 375/768/1280 layouts, keyboard inputs, validation summary, both themes pass. BRB YES required.

### P2.8 — Append-only neutral decision flow

**Scope:** capability-guarded review and confirm routes, readiness service, append-only revisions/approvals/invalidations, compatibility projection, audit entry, stale diff/re-review.

**Acceptance:** no option is selected on load for accept/conditional/decline/no-advice fixtures; a user cannot confirm until critical evidence/gates/material plan assumptions are resolved; no-advice human decision works with rationale; actor comes from session; all bound ids/versions and commercial snapshot are persisted; stale source/effective record/criteria/gate/plan rejects atomically with useful diff; high-risk cases require a different second actor; prior decisions remain replayable; screenshot-14 never contributes an advisory Accept to decision or audit metrics. BRB YES required.

### P2.9 — LA response preparation and disposition seam

**Scope:** response versions, deterministic confirmed-decision template, prepare/copy/download UI/actions, stale response handling, timeline entries, read-only `not_recorded` disposition handoff.

**Acceptance:** response cannot be prepared from an unconfirmed/pending-approval decision; it binds the exact decision and plan/rate snapshot; only HCA/RMN flat lines appear; no Ofsted/home boilerplate; copy/download actions are content-minimised and auditable; response body never appears in events/logs; superseding a decision leaves the old response historical and marks it stale; there is no send/outcome/handover mutation. BRB YES required.

## 8. Testing strategy

### Fixture matrix

Repair and extend `src/lib/referrals/fixtures/matrix.ts`; do not introduce a parallel fixture catalogue. Add deterministic archetypes for:

- adult complex-care accept, conditional, decline;
- child complex-care under approved TDDI representation, explicitly not Ofsted;
- genuine out-of-scope work unrelated to age/regulator;
- screenshot-14 indeterminate and terminal evaluation failure;
- verified, corrected, and marked-missing critical fields;
- contradictory source anchors and source-without-accessible-text;
- amendment candidate, active superseding source set, failed re-extraction, material and non-material diffs;
- all seven human gate states, draft and approved rules, missing historical snapshot;
- 1:1/2:1/3:1 HCA/RMN role mixes and rate-card change;
- plan/effective-record/gate/decision optimistic conflicts;
- manual no-advice decision, normal decision, risk-class second approval, supersession/invalidation;
- current/stale response and `not_recorded` disposition seam.

Every fixture must parse through the real contracts. Add a guard that rejects unknown keys in fixture source objects or explicitly checks important fields survived parsing, preventing the current `ratio`/`nursingCover` drift.

### Screenshot-14 permanent regression

The screenshot-14 fixture remains mandatory across:

- queue row and My work;
- Overview and quality panel;
- Evidence and gates;
- staffing;
- decision review and confirmation;
- LA response eligibility;
- audit/report inclusion helpers.

Assertions: durable state is indeterminate; presentation is “No recommendation”; no success/Accept badge; no decision option preselected; manual evidence/gate workflow remains available; no response draft is produced until an explicit human decision; recommendation/override metrics exclude the stub.

### Automated layers

- Pure domain tests for effective-record patching, materiality, readiness, rate selection, fixed-hour arithmetic, approval risk, and response templating.
- Repository/transaction tests for append-only writes, supersession, dual-write projections, unique revisions, stale conflicts, and rollback on partial failure.
- Migration tests plus disposable-Neon execution/backfill/reconciliation.
- Route/action authorization tests for every new capability and cross-referral/document id.
- Contract/DTO leak tests: list data never gains extract/sources/chat/response; event/audit payloads never gain correction/response free text.
- Evaluation tests proving exact criteria snapshot/rule grounding and effective-record version persistence without changing the seven-gate/RecommendationResult contract.
- Commercial forbidden-key tests across working-plan, chat op, route body, response, and UI view model.
- Component interaction tests for focus return, error summaries, stale conflict recovery, and nothing-preselected.
- Playwright end-to-end flows: evidence correction → gate review → plan save → decision → response, plus amendment invalidation and no-advice manual path.

### Visual/accessibility/BRB

- Screenshot baselines at 375×812, 768×1024 or 1024×768, and 1440×1000; light/dark and reduced motion where interaction changes.
- Mask only genuinely dynamic ids/timestamps; never mask decision state, totals, rule status, or readiness blockers.
- Test keyboard-only, screen-reader task completion, 400% zoom/reflow, slow network, and source access failure.
- Every UI PR receives a running-app BRB auto pass from the real user perspective. Acceptance is all scenarios passed or explicitly phase-deferred and no open P0/P1. Interactive BRB triage remains a separate session if defects need human prioritisation.
- Re-run P1 queue/source tasks as regressions on every P2 UI PR; P2 must not push the first actionable row below the fold or slow source finding.

## 9. Rollout and operational safety

- Keep `WORKSPACE_V2_ENABLED` and cohort gating; add narrower server-side P2 capability/subfeature flags if partial domain PRs land before UI.
- Keep old `/queue`, `/referrals/[id]`, current `human_review`, and extract projection functional through P4.
- New links always use `/workspace/**`; decision/response are stable routes, not modal/sheet-only state.
- Pilot only synthetic fixtures and consented development data until live migration, authz, source-security, and BRB gates pass.
- Never use live referral data as screenshot golden content.
- On rollback, disable new writers/readers and return to compatibility projections. Do not delete field reviews, decisions, approvals, or responses that humans created.
- Add PII-safe reconciliation metrics: counts of evidence heads, orphan version ids, decision projection mismatch, response bound to non-current decision, and failed backfill ids. Do not log field values or response content.

## 10. Open questions / risks

| Question / risk | Needed by | Recommended default |
|---|---|---|
| What exactly is TDDI in the contract and criteria model, and who signs its regulatory basis? | Before P2.0 merge | Clinical Lead/RM-authored ADR; coordinated contract v2; no silent CQC relabel and no Ofsted live path. |
| Which existing roles receive `clinical:decide`, `clinical:second_approve`, `evidence:verify`, `commercial:approve`, source view, and source download? | Before mutation UI | Preserve current access only behind flags, but require captain confirmation before production enablement; second approver must be distinct. |
| Does “nursing cover” always consume one full 168-hour RMN post, or may HCA/RMN hours split more granularly while preserving total hours? | Before P2.4 contract freeze | Preserve the current provision intent: one full RMN post where required, remaining ratio hours HCA; expose only if clinically signed off. |
| Which complex-care fields are critical/material, and which corrections invalidate gates/plan/decision? | Before P2.2/P2.5 | Versioned line registry signed by Clinical Lead/RM; default uncertain fields to material, not harmless. |
| Should P2 also redesign initial intake for multi-file envelopes? | Before P2.1 UI scope | Build shared backend now; expose amendment UI only unless captain explicitly expands P2. |
| Does P2 need review-chat parity or is manual plan editing sufficient until cutover? | Before P2.7 | Manual editor first; narrow chat only if parity is required and it fits a separate PR. |
| Is an app admin rate editor required in P2 despite P4 owning admin screens? | Before P2.4 release | P2 table/repository/version publication; P4 UI. No runtime constants. |
| What exactly should “disposition skeleton” show? | Before P2.9 | Derived `not_recorded` handoff only; P3 owns outcomes, owners, reasons, capacity release, and handover. |
| What happens to a confirmed/prepared response after a later material amendment? | Before P2.8 | Preserve history, append invalidation, require a new decision/response; never overwrite or silently keep current. P3 must later address already-sent responses. |
| Current P1 My work is role-labelled but uses the same global 50-row queue and is not service-line filtered. | P1 study / before P2 cohort | Treat study findings as a prerequisite; repair P1 scoping separately rather than burying it in decision work. |
| The source route streams inline content broadly and current upload security is not a full quarantine/sniffing pipeline. | Before amendment/source UI | Add byte-sniff/security state and capability-based safe delivery before making amendments active. |
| Criteria rows are mutable while decisions require historical replay. | Before P2.3 | Persist immutable ruleset snapshot per hash/evaluation; never reconstruct an old decision from today’s rows. |
| Live Neon migration/backfill behavior was not exercised in P0. | Every P2 migration | Disposable Neon is a hard PR gate, not a post-merge task. |

## 11. Rejected alternatives

| Alternative | Rejection reason |
|---|---|
| Mutate `referrals.extract` when a reviewer corrects a field | Destroys model/source history and prevents replay. Use an append-only overlay and compatibility projection. |
| Store only the latest correction per field | Cannot explain changes, actors, reasons, or the exact effective record used by a decision. |
| Treat an amended pack as a new referral/duplicate | Splits one case history and leaves stale facts/decisions active. Use source-set versions. |
| Auto-merge documents/referrals on hash | Forwarded wrappers and legitimate amendments can share content; it also risks cross-scope existence leaks. |
| Reuse the current criteria table at display time for old evaluations | A hash is not replayable if rows mutate. Persist the immutable snapshot used. |
| Add `ruleId` directly to frozen `GateResult` in P2 | Causes unnecessary shared-contract churn. Persist a server-side grounding sidecar; coordinate contract changes separately. |
| Keep both current pricing engines active and hide forbidden lines in the P2 UI | Forbidden fields would still affect stored totals, chat, responses, and audit. Replace the active domain model, not just its presentation. |
| Add RMN hours above the ratio | Violates the fixed total-hour rule and is the current P1 defect. Role hours must sum to the ratio total. |
| Let the model/chat calculate price or choose an ad hoc rate | Money and hours are deterministic server arithmetic against an immutable rate-card version. |
| Auto-pass or delete `compatibility_matching` for solo settings | The captain resolved this as criteria re-scope with evidence/rationale, while all seven gates remain. |
| Treat children as Ofsted or send them to refer-on | Directly contradicts the binding TDDI rule. |
| Overwrite `human_review` as the decision record | Loses revisions/supersession and cannot bind full evidence/criteria/plan state. Keep it only as a compatibility projection. |
| Preselect the advisory decision or make “agree” the easy path | Recreates screenshot-14/automation-bias risk. Human choice starts empty in every state. |
| Block human decisions whenever recommendation is null | No-advice is a valid manual workflow; the current action’s non-null recommendation precondition must be replaced. |
| Use a modal or drag-dismiss sheet for final confirmation | The settled design requires stable routes, explicit Cancel, focus continuity, and mobile task safety. |
| Add work items, SLA, capacity, outcome/handover, notifications, or reporting in P2 | Those are P3/P4 and would couple human-truth migrations to unvalidated operational policy. |
| Treat BRB as the P1 moderated study | BRB verifies the running app; it does not capture real staff comprehension/task-study evidence. Both gates are needed. |
| Destructively roll back append-only human records | Audit/review truth must survive. Roll back behavior through flags/dual-read and forward-fix schema, not erase history. |
| Add Storybook for P2 components | The master explicitly rejects a second app/config surface; use deterministic fixture routes and Playwright. |

## 12. Evidence and commands run

Key commands and findings:

- `nl -ba /Users/leebarry/firstmate/data/sr-plan.md` — confirmed P2 at line 55, P3/P4 boundary at 56–58, and binding business rules at 60–64.
- `git fetch origin main`, `git switch --detach origin/main`, `git rev-parse HEAD` — final baseline `7103f67c15c65c8dbb548b041ad8cfcd13a9ba1a` after PR 24 merged.
- `gh-axi pr view 22 --full`, `23 --full`, `24 --full` — verified P0/Clearline/P1 intent and validation history.
- `git diff --stat` / `git diff --name-status` for P1 — identified the 40-file P1 surface and its new workspace, DTO, queue, pricing, source, fixture, migration, and test seams.
- `git grep -n -i -e ofsted -e tddi origin/main -- ...` — found live Ofsted/TDDI references across 29 non-doc/package files, including contract, prompt, criteria, evaluation, legacy UI, commercial comments, and tests; confirms removal is coordinated work, not copy-only.
- `rg --files src/lib src/app db/migrations migrations docs e2e` and targeted `nl -ba` reads — inspected contracts, evaluation, criteria, ingestion/jobs, DB repositories/migrations, commercial/working plan/chat, audit, P1 workspace, source route, fixture matrix, and QA report.
- Attempted focused Vitest command for flat pricing, quality panel, fixtures, and presenter. It did not run because dependencies are not installed in the disposable scout worktree (`sh: vitest: command not found`). No implementation validation claim depends on that attempt; the source test itself documents the incorrect 2:1 expectation.

## Conclusion

Start P2 immediately with the additive evidence/versioning, grounding, flat-commercial, capability, fixture, and migration foundations. Hold all material interaction work behind the incomplete P1 moderated study and hold TDDI/decision authority behind their named clinical/product decisions. The critical architectural move is to make source sets, effective records, criteria, plans, decisions, and responses independently versioned and explicitly bound; that gives P2 durable human truth while preserving the P0 safety state, the P1 proof slice, and a clean P3 operational boundary.
