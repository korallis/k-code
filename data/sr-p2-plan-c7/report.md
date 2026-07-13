# Service-Referral P2 ("Human truth") — Implementation Plan (Draft C7)

**Scout:** sr-p2-plan-c7 (planning only — no implementation code written)
**Date:** 2026-07-13
**Base:** `origin/main` @ `7103f67` — *"feat(workspace): add referral operations pilot workspace (#24)"*. P1 merged to main mid-scout (PR 24); `git diff origin/fm/sr-p1 origin/main` is empty, so the P1 branch tree and merged main are identical. All references below are to merged main.
**Plan source:** `/Users/leebarry/firstmate/data/sr-plan.md` (converged rebuild plan, incl. §4b binding business rules).

---

## 0. Executive summary

P2 is the phase where humans start *writing* truth into the workspace: verified fields, amended documents, gate resolutions, append-only decisions, LA responses, and dispositions. P1 deliberately shipped the read-only shell for exactly these surfaces (the Evidence "Action" pane literally renders a "P2" badge — `src/app/workspace/[serviceLine]/_components/evidence-panes.tsx:133-139`), so P2 is mostly *filling in prepared sockets*, not restructuring.

The plan below:

- Enumerates P2 scope faithfully from `sr-plan.md:55` and cross-references each item to its defining decision row in §2 of the plan (§1 below).
- Applies the three §4b binding rules: **TDDI children in scope / no Ofsted machinery** (a behavior repoint, not a contract break), **fixed ratio hours** (already implemented in P1's `flat-pricing.ts`), and **flat charge-out pricing with an admin-editable rate table** (new table + wiring) (§2).
- Maps every P1 component to extend / replace / untouched (§3).
- Specifies six additive, reversible Neon migrations (`0011`–`0016`) following the repo's established patterns: `IF NOT EXISTS` DDL, append-only triggers copied from `migrations/0002_audit_log.sql`, idempotent backfills copied from `db/migrations/0008_evaluation_runs.sql` (§4).
- Splits work into a **safe-to-build-now core** (all data models, domain logic, engine repoints — ~60% of the phase) and a **study-informed remainder** (interaction design of verification, assessment review, and the decide route) so implementation can start before the P1 moderated task study reports (§5).
- Extends the P0 fixture matrix and the screenshot-14 regression into every new mutation surface (§6).
- Sequences ten single-PR milestones with acceptance criteria, each UI-bearing PR gated on a BRB real-user QA pass (§7).

**Headline recommendations** (each argued in place):

1. Field verification is a new append-only table `referral_field_reviews` + a pure "effective record" library; the extract is never mutated (plan §2 "Field verification" row mandates this).
2. Decisions are a new append-only `referral_decisions` table with derived (never mutated) currency: supersession pointers + version bindings, second-person approval as an append-only `referral_decision_approvals` table. The workspace decide flow **dual-writes** the legacy `referrals.human_review` column when legacy-compatible so the old UI stays truthful during the parallel build.
3. The §4b Ofsted rule is implemented as an **engine repoint** (stop routing on `regime === "ofsted"`, retire the 7 Ofsted corpus rules via `effective_to`, add TDDI citations), *not* a contract change — `regimeSchema` (`src/lib/contracts/common.ts:17`) stays frozen until the coordinated contract v2 that `sr-plan.md:11` and `:32` already anticipate.
4. Pricing = P1's `computeFlatChargeOut()` promoted to read an admin-editable, versioned `charge_out_rate_cards` table (seeded HCA £32/h, RMN £65/h), with the decision record snapshotting the priced basis. The legacy working-plan/on-cost machinery is **not** surfaced in any workspace pricing window (§4b rule 3) but is left intact for the legacy UI.

---

## 1. What sr-plan.md scopes into P2 — faithful enumeration

`sr-plan.md:55` (verbatim):

> **P2 - Human truth**: field verification overlay + effective record; amendments/supersession; per-gate criteria review UI; staffing/price decomposition; append-only decisions + neutral review/confirm; LA response prep; disposition skeleton.

Each item, with its defining spec elsewhere in the plan:

| # | P2 item | Defining spec | What it concretely means |
|---|---|---|---|
| 1 | Field verification overlay + effective record | §2 "Field verification" (`sr-plan.md:23`) | Verify / Correct / Mark-missing per field; append-only `referral_field_reviews` (actor, reason, version); "effective record" = extract + overlay applied at read time, extract never mutated; criticality registry per service line; Evidence tab bidirectional source↔field highlighting |
| 2 | Amendments / supersession | §2 "Intake" row, amendment-flow clause (`sr-plan.md:37`) | Document-set versions, supersession/contradiction states, field-level diff, deliberate re-extraction, pending-decision invalidation |
| 3 | Per-gate criteria review UI | §2 "Review depth" (`:25`), "Gates" (`:32`), captain decision 2 (`:69`) | Explicit resolution of critical/unassessed gates for EVERY decision (consequence-driven, no confidence shortcut, no click theatre for verified non-critical gates); show the rule/citation basis per gate; compatibility_matching re-scoped for solo settings with recorded rationale |
| 4 | Staffing/price decomposition | §3 screen list (`:49`) + §4b rule 3 (`:64`) | "Staffing & price" tab shows hours-by-role × rate only; rates in an admin-editable table; formula-expandable lines |
| 5 | Append-only decisions + neutral review/confirm | §2 "Decisions" (`:24`), §1 "no preselected decisions, ever" (`:15`), §2 "Motion" (`:36`) | Append-only `referral_decisions` with supersession; confirm sheet shows visible binding (extract/evidence/criteria/plan versions, provision label, fee); stale-version → inline diff → explain change → re-review; second-person approval by risk class (decline / crisis / safety-signal / low-evidence); material source change auto-invalidates a pending decision; decision flow is stable routes with explicit Cancel |
| 6 | LA response prep | §3 screen list (`:49`) | Prepare / copy / download; typed sent state (real outbox/sending is P3 `:56`) |
| 7 | Disposition skeleton | §2 "Outcomes/closure" (`:44`) scoped down; full outcomes/handover is P3 (`:56`) | Typed outcome data model + minimal record action; reporting and handover records deferred |

**Boundary notes (what P2 explicitly is *not*):** work items/assignment, SLA calendars/pauses, in-app outbox, capacity model, presence chip, and decision-form draft persistence are all P3 (`sr-plan.md:56`); reporting/admin suite is P4 (`:57`). The scoped RBAC policy engine is its own pre-P5 workstream (`:34`) — P2 only adds capability *names* as a static derivation (see §4.7).

### 1.1 Ambiguities found, with proposed resolutions

Where the plan is ambiguous I state the ambiguity and propose a resolution rather than silently choosing:

**A1 — Does "amendments/supersession" include the full multi-document intake envelope?** The Intake row (`sr-plan.md:37`) bundles envelope upload (client-to-Blob, per-file progress, recoverable draft) *and* the amendment flow in one cell, but the P2 line names only "amendments/supersession". Today upload is single-file per request with a multi-file guard (`src/app/api/v1/referrals/upload/route.ts:178-190`, README "Runtime Surface").
*Proposed resolution:* P2 builds the **document-set data model + amendment upload onto an existing referral** (which forces multi-document support in storage, provenance, and the source-delivery route), and does **not** rebuild first-contact intake UX. The `referral_documents` model (§4.2) is designed so the envelope intake can later ride it additively. If the captain wants envelope intake pulled into P2, it appends as one extra PR; nothing below blocks it.

**A2 — What exactly is the "disposition skeleton" vs P3 "outcomes/handover"?**
*Proposed resolution:* P2 = `referral_dispositions` table (typed outcomes `won | lost_price | lost_capacity | withdrawn | no_response` + typed reasons per `sr-plan.md:44`), a contract, one "Record LA outcome" action available once a decision + LA response exist, and a Timeline entry. P3 adds handover records, named disposition owner workflows, and the decided-but-no-outcome reconciliation report; P4 adds reporting.

**A3 — Does the solo-settings compatibility_matching re-scope land in P2 or with P5's line-scoped criteria?** Captain decision 2 (`sr-plan.md:69`) says it "lands with the line-scoped criteria work", which could be read as P5. But Muve's capacity truth is solo one-bed units (`:31`), so *every* real complex-care referral hits this gate, and P2's criteria review UI would otherwise display a group-assumption rule (`cqc-compatibility-matching-1` cites "risk to the existing group" — `src/lib/criteria/corpus.json`) that is structurally wrong for the active service line.
*Proposed resolution:* land the re-scoped compatibility rule **text + recorded rationale in P2** as part of the corpus v2 changes (§4.4) — this is a criteria-content change, not the line-scoping *mechanism* (a `service_line` column stays deferred to the pre-P5 criteria workstream). Rationale is recorded in a new nullable `rationale` column + criteria docs, per captain decision 2's "recorded rationale, NOT an auto-pass and NOT gate deletion".

**A4 — Rate-table admin surface vs "Admin is P4".** §4b rule 3 says rates live in an admin-editable table; the roadmap puts admin surfaces in P4 (`:57`).
*Proposed resolution:* the binding §4b rule wins for this one table: P2 ships a minimal rates editor on the existing workspace Settings page (`src/app/workspace/[serviceLine]/settings/page.tsx`, currently a placeholder shell), guarded by a new `rates:manage` capability. The P4 admin suite later absorbs it.

**A5 — Where do workspace decisions leave the legacy `human_review` path?** Legacy review writes `referrals.human_review` via `recordHumanReview` (`src/lib/db/referrals.ts:926-959`) with guards `status IN ('evaluated','needs_review') AND recommendation IS NOT NULL`. The plan's manual-evidence-mode principle (`sr-plan.md:38`) and the decisions row imply humans can decide even when evaluation failed.
*Proposed resolution:* the workspace decide action writes `referral_decisions` always, and **dual-writes** legacy `human_review` in the same transaction *when the legacy guard would accept it*. A decision recorded on an `evaluation_failed` referral exists only in the new table; the legacy UI keeps showing the failed status truthfully (no lie, just less detail). Documented as a known parallel-build gap, closed at P4 cutover.

**A6 — "Shift view" in the Staffing & price screen spec.** §3 (`:49`) predates §4b; with fixed 168/336/504 hours and flat rates there is no shift-dependent price.
*Proposed resolution:* P2 decomposition = per-role lines (hours × rate) with an expandable formula row — which P1 already renders read-only (`src/app/workspace/[serviceLine]/referrals/[id]/page.tsx:350-392`). A shift-pattern visualisation is dropped unless the task study shows reviewers need it operationally (it would be presentational only; flagged study-informed).

**A7 — "Pending decision" auto-invalidation semantics under append-only rows.** `sr-plan.md:24` says "Material source change auto-invalidates a pending decision" but rows are append-only.
*Proposed resolution:* invalidation is **derived, never mutated** (same philosophy as the derivation-constrained work-item machine, `:27`): each decision row stores the extract/criteria/rate-card versions it bound; an amendment bumps `referrals.extract_version`; a decision whose bindings no longer match current state presents as *invalidated/stale* and the decide route forces the stale-diff → explain → re-review path. A content-minimised `referral_events` row records the invalidation moment for the timeline.

**A8 — What is "genuinely out-of-scope" once Ofsted-badged children are in scope?** §4b rule 1 keeps the intake-exceptions lane "only for genuinely out-of-scope work". The current fixture `out_of_scope` (`src/lib/referrals/fixtures/matrix.ts:348-401`) already models this as a CQC-regime `placementType: "other"` referral, not an Ofsted one — good. But no captain-confirmed list of refused work exists (fostering? residential school? pure accommodation?).
*Proposed resolution:* P2 does **not** build automatic out-of-scope classification. It ships a manual "Mark out of scope / refer on" affordance in the decide surface (the standard accept/decline control never renders once marked — `sr-plan.md:33`), recorded as a decision-kind `refer_on` row. Automatic detection waits for the captain's refused-work list (open question Q2). The full refer-on lane with owner + SLA lands with P3 work items.

---

## 2. The §4b binding rules — exact code implications

### 2.1 Rule 1: children under TDDI; no Ofsted machinery

Current Ofsted machinery inventory (all verified on main):

| Site | Behavior today |
|---|---|
| `src/lib/contracts/common.ts:17` | `regimeSchema = z.enum(["cqc","ofsted"])` — frozen contract; CLAUDE.md forbids widening without `CONTRACT_VERSION` bump |
| `src/lib/referrals/service-line.ts:23-27` | `isOutsideActiveServiceLine(regime) := regime === "ofsted"` |
| `src/lib/evaluation/engine.ts:329-334` | appends the outside-service-line review reason → every `ofsted` extract forces `requiresHumanReview` |
| `src/lib/jobs/pipeline.ts:695-703` | outside-service-line referrals skip the deterministic commercial overlay |
| `src/lib/criteria/corpus.json` | 7 of 14 rules are `regime:"ofsted"`, citing Children's Homes (England) Regulations 2015 |
| `migrations/0001_create_criteria_rules.sql:11` | `regime` CHECK constraint allows `('cqc','ofsted')` |
| `src/lib/staffing/childrens.ts` | ratio-driven children's WTE calculator — **has no runtime callers** (verified: referenced only in its own tests); shape-coupled to `StaffingRecommendation` only |
| Legacy `(app)` detail banner | Ofsted outside-service-line banner (legacy surface, untouched until cutover) |

**Reading of TDDI** (to be confirmed by discovery per §4b rule 1's parenthetical): TDDI is the standard CQC abbreviation for the regulated activity **"Treatment of Disease, Disorder or Injury"** — i.e. Muve takes children under its CQC registration for clinical care, which is age-agnostic; Ofsted regulates children's *homes* (accommodation), which Muve is not providing. This is why "Ofsted is NOT required". The plan records this reading as an assumption; PR-P2.4's acceptance criteria include the captain/clinical lead confirming the citation set before rules leave `draft_unverified`.

**Implementation (all behavior, no contract break):**

1. **Do not touch `regimeSchema`.** Removing the `"ofsted"` literal is a breaking contract change; `sr-plan.md:11`/`:32` already reserve a coordinated contract v2 for "no advice" and `not_applicable` semantics — regime cleanup joins that vehicle. Until then the literal is a harmless vestige (DB CHECK constraints likewise stay).
2. **Repoint routing:** delete the *use* of `isOutsideActiveServiceLine` in `engine.ts:329-334` and `pipeline.ts:695-703` (children's referrals get the commercial overlay and full evaluation like any other). Keep `service-line.ts` as the home of the active-line constant; its outside-line predicate is replaced by the manual refer-on decision (A8).
3. **Extraction prompt:** update the WS-2 prompt so children's referrals are not classified `regime:"ofsted"`; regime is `cqc` for everything Muve serves, with age carried by `person.age`/`dob` as today. (Extraction may still emit `ofsted` from old habits; step 2 makes that harmless — it just evaluates.)
4. **Criteria corpus v2** (§4.4): retire the 7 `ofsted-*` rows by setting `effective_to` (reversible, not deleted); add TDDI-basis citations to the complex-care ruleset where children-specific anchors are needed; record the TDDI regulatory basis in `docs/` criteria documentation per the captain's note.
5. **Transitional safety:** until the TDDI criteria rows exist *and* a clinical lead has signed them off, referrals with `person.age < 18` add a review reason `tddi_criteria_draft` (new code in `pipeline.ts`'s `getReviewReasonCode` map, `pipeline.ts:460-498`). This is not an Ofsted lane — the referral evaluates fully, prices fully, and appears in the normal queue; it simply cannot leave human review while its rule basis is unapproved. Cheap to remove: one predicate.
6. **Fixtures:** `out_of_scope` already models a non-Ofsted exception (`matrix.ts:367-369` comment shows this was anticipated); add a `child_tddi` archetype that evaluates in scope (§6.2).

### 2.2 Rule 2: fixed ratio hours (1:1=168, 2:1=336, 3:1=504)

Already implemented in P1: `RATIO_WEEKLY_HOURS` (`src/lib/workspace/flat-pricing.ts:14-18`) and `weeklyHoursForRatio()` (`:57-65`, generalising to `workers × 168` beyond 3:1). The Staffing tab already prints "Hours: 1:1=168 · 2:1=336 · 3:1=504" (`referrals/[id]/page.tsx:388`). **P2 keeps this module as the single hours authority** and must not re-introduce the legacy `DEFAULT_WEEKLY_HOURS_PER_CONCURRENT_POST`-with-absence-uplift math (`src/lib/commercial/constants.ts:23,40`) into any workspace window.

### 2.3 Rule 3: flat charge-out pricing; admin-editable rate table

P1 hardcodes `FLAT_CHARGE_OUT_PENCE = { hca: 3_200, rmn: 6_500 }` (`flat-pricing.ts:21-24`) and the e2e suite already asserts the Staffing tab shows flat charge-out with **no** on-cost/absence/property lines (`e2e/workspace-p1.spec.ts:71-75`). P2:

- Adds the versioned `charge_out_rate_cards` table (§4.3), seeded v1 = HCA 3200p, RMN 6500p.
- `computeFlatChargeOut()` gains a `rates` parameter; a server loader resolves the active card and falls back to the constants when the table is empty/unreachable (same fallback philosophy as `src/lib/criteria/repository.ts`).
- Every price display carries the rate-card version; every decision snapshot embeds the priced lines (so a later rate edit never rewrites history).
- The legacy commercial core (`src/lib/commercial/pricing.ts` on-cost/absence/margin, `roles.ts` £14/£28 *pay* rates, `referral_working_plans`, review-chat ops) **remains untouched and legacy-only**: those are pay-cost models, not LA charge-out, and §4b forbids their factors in pricing windows. The review-chat seam (`src/lib/review/chat-service.ts`, 10 allowlisted op kinds in `src/lib/contracts/chat.ts:16-27`) is not extended to workspace pricing in P2 — see Rejected alternatives R4 and open question Q5.

---

## 3. How P2 builds on the P1 proof slice

P1 inventory and treatment (all paths on main @ 7103f67):

| P1 component | P2 treatment | Notes |
|---|---|---|
| `src/app/workspace/[serviceLine]/workspace-shell.tsx`, `src/lib/workspace/nav.ts` | **Extend (light)** | Nav unchanged structurally; Settings loses `comingSoon` when the rates editor lands (nav.ts:50-56). Capacity/Reports stay P3/P4 placeholders |
| `src/lib/workspace/rank.ts` (queue-rank-v1) | **Untouched** | Versioned policy; SLA calendars are P3. Do not fork the version in P2 |
| `src/lib/workspace/queue-dto.ts` + `src/lib/db/referrals.ts:556-730` (`listWorkspaceQueueRows` SQL) | **Extend (additive)** | Add decision-state scalars (current decision kind, awaiting-second-approval, response-sent) as new columns in the CTE + DTO; extend `QUEUE_DTO_FORBIDDEN_KEYS` (queue-dto.ts:26-38) with `fieldReviews`, `decisions`, `documents`, `laResponse`, `correctedValue`, `reason`, `rationale` and keep the leak test authoritative |
| `src/lib/workspace/queue-source.ts` (`getWorkspaceReferral`) | **Extend** | Detail loader additionally fetches field reviews, documents, decisions, LA responses (parallelised — `Promise.all`, per the plan's parallelized-detail-reads note `sr-plan.md:39`) |
| `src/lib/workspace/quality-panel.ts` | **Extend** | `CRITICAL_FIELD_PATHS` (:38-47) moves out into the shared criticality registry (§4.1); evidence coverage becomes effective-record-aware (verified/corrected fields count differently from merely-present); unresolved-gate count consumes gate resolutions |
| `src/lib/workspace/flat-pricing.ts` | **Extend** | Rates injected from rate card; pure compute core preserved (tests keep passing with constants) |
| `src/lib/workspace/my-work.ts` | **Extend (light)** | Buckets for "awaiting second approval" and "decided, response not prepared"; keep the not-a-KPI-dashboard rule (my-work.ts:4) |
| `src/app/workspace/[serviceLine]/_components/evidence-panes.tsx` | **Replace contents, keep layout** | The three-pane layout is fixed by design (:139); Action pane becomes the real Verify/Correct/Mark-missing surface; Record pane renders the effective record with per-field status + provenance links; Source pane gains a document list (multi-doc) |
| `src/app/workspace/[serviceLine]/referrals/[id]/page.tsx` | **Extend** | Tabs stay (`:37-43`); the "read-only / Decision mutation is Phase 2" copy (:147,:196-198) is replaced by the live surfaces; header gains decision-state chip; new `decide/` sub-route |
| `src/app/api/v1/referrals/[id]/source/route.ts` | **Extend** | Delivery by document id from `referral_documents` (today it derives one path from the upload idempotency key via `getReferralUploadDocumentPath`, `db/referrals.ts:755-763`); authz + private-cache headers preserved |
| `src/lib/workspace/fixtures-bridge.ts` + `src/lib/referrals/fixtures/matrix.ts` | **Extend** | New archetypes (§6.2); `indeterminate_stub` (`fixture-screenshot-14`, matrix.ts:290-304) is the regression anchor and must not change |
| `src/lib/features/workspace.ts` (flag + cohort), `src/lib/auth/session.ts` pilot seam | **Untouched** | The P2 surfaces ship behind the same `WORKSPACE_V2_ENABLED`/`WORKSPACE_V2_COHORT` gate |
| `src/lib/referrals/present-recommendation.ts` | **Untouched** | The indeterminate-presentation safeguard stays the single funnel; the decide route consumes `presentRecommendation().advisoryDecision` exactly as the legacy action does (`src/lib/referrals/actions.ts:53-66`) |
| Legacy `(app)` surfaces, `src/lib/commercial/*`, review-chat seam | **Untouched** | Additive-only during the rebuild (`sr-plan.md:15`); dual-write keeps legacy truthful |
| `src/lib/staffing/*` (WTE library) | **Untouched** | Unwired calculators (no runtime callers); §4b sidelines WTE for pricing. Leave for potential P3 capacity use |
| `src/design/clearline/*` | **Extend (components only)** | New primitives needed: form field row with status chip, confirm-sheet layout, diff row. Tokens untouched |
| Contracts (`src/lib/contracts/*`) | **Extend (additive only)** | New files: `field-review.ts`, `document.ts`, `decision.ts`, `rate-card.ts`, `disposition.ts`; one additive optional field on `gateResultSchema` (§4.4). `CONTRACT_VERSION` (common.ts:76) unchanged — nothing existing is narrowed or re-shaped |

---

## 4. Data model & migrations (Neon)

House rules honored throughout (verified against the repo): migrations live in `db/migrations/` (tracked in `_migrations`, each file applied whole in its own transaction — `scripts/db/migrate.mjs:28-40`); criteria-set migrations live in `migrations/` (tracked in `schema_migrations`); append-only enforcement copies the trigger pattern of `migrations/0002_audit_log.sql:24-38`; backfills use the idempotent `WHERE NOT EXISTS` pattern of `db/migrations/0008_evaluation_runs.sql`. All migrations below are **additive**: no column drops, no type narrowing, no rewrites of existing rows other than defaulted new columns.

**Reversibility posture:** rollback for additive tables = flag the feature off (`WORKSPACE_V2_ENABLED` or per-PR env guard) and leave the table in place; physical `DROP TABLE` is reserved for dev/preview branches. Append-only clinical tables (`referral_field_reviews`, `referral_decisions`, `referral_decision_approvals`) must never be dropped once production rows exist — same posture as `audit_log`. Every migration is rehearsed on a Neon branch before merge (acceptance criteria, §7).

**Numbering note:** migration file numbers are assigned in PR *landing* order (§7), not this document's scope order — the runner tracks by filename and applies any pending file, but monotonic numbering keeps the directory readable. Hence rate cards = `0012` (lands in P2.3) and documents = `0013` (lands in P2.6), while the sections below follow scope order.

### 4.1 `0011_referral_field_reviews.sql` — verification overlay

```sql
CREATE TABLE IF NOT EXISTS referral_field_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_id UUID NOT NULL REFERENCES referrals (id) ON DELETE CASCADE,
  extract_version INT NOT NULL,          -- binds the review to the extract it reviewed
  field_path TEXT NOT NULL,              -- canonical dot path, e.g. 'staffingSignals.requestedRatio'
  action TEXT NOT NULL CHECK (action IN ('verify','correct','mark_missing')),
  corrected_value JSONB,                 -- present iff action='correct'
  reason TEXT,                           -- free text; NEVER copied into events/logs
  actor_id TEXT NOT NULL,
  actor_role TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- append-only triggers (audit_log_immutable pattern)
-- INDEX (referral_id, field_path, created_at DESC, id DESC)
```

Companion code:

- `src/lib/contracts/field-review.ts` — zod schemas (`fieldReviewActionSchema`, `fieldReviewRecordSchema`); field paths validated against the extract schema's known paths.
- `src/lib/referrals/effective-record.ts` — **pure** `buildEffectiveRecord(extract, reviews[]) → { effective: ReferralExtract-shaped view, fieldStatus: Map<path, 'verified'|'corrected'|'marked_missing'|'unreviewed'>, appliedReviews }`. Latest review per path wins; only reviews with `extract_version === current` apply (older ones surface in history/diff only). This library is consumed by the Evidence Record pane, the quality panel, flat pricing (ratio comes from the *effective* record), the decide route, and the LA response builder — one merge algorithm everywhere.
- `src/lib/referrals/criticality.ts` — the criticality registry: per service line, the field paths that demand verification before decide (seeded from P1's `CRITICAL_FIELD_PATHS`, quality-panel.ts:38-47, which the panel then imports). Marked DRAFT pending the task study + RM sign-off (`sr-plan.md:23` "Criticality registry per service line").
- `src/lib/db/field-reviews.ts` — insert + list; inserts also append a content-minimised `referral_events` row (`stage='evidence', status='field_reviewed', detail={ fieldPath, action, extractVersion }` — never `corrected_value` or `reason`, matching the chat-turns privacy pattern, `db/migrations/0006:2-4`).

Privacy note for the DPIA (`docs/dpia.md` update rides PR-P2.2): corrections are special-category data handling and also *support* UK GDPR Art. 16 rectification — worth recording as a compliance positive.

### 4.2 `0013_referral_documents.sql` — document sets, extract versions (amendments)

```sql
CREATE TABLE IF NOT EXISTS referral_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_id UUID NOT NULL REFERENCES referrals (id) ON DELETE CASCADE,
  blob_path TEXT NOT NULL,
  original_filename TEXT,
  media_type TEXT,
  byte_size BIGINT,
  content_fingerprint TEXT,              -- sha256, duplicate-candidate cue within scope
  kind TEXT NOT NULL CHECK (kind IN ('original','amendment')),
  doc_set_version INT NOT NULL,
  superseded_by UUID REFERENCES referral_documents (id),
  uploaded_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE referrals ADD COLUMN IF NOT EXISTS extract_version INT NOT NULL DEFAULT 1;

CREATE TABLE IF NOT EXISTS referral_extract_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_id UUID NOT NULL REFERENCES referrals (id) ON DELETE CASCADE,
  version INT NOT NULL,
  extract JSONB NOT NULL,
  doc_set_version INT,
  model_id TEXT, prompt_version TEXT,    -- extraction provenance
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (referral_id, version)
);
```

Backfills (idempotent, 0008-style): one `referral_documents` row per referral with an `upload_idempotency_key` (path = `referrals/uploads/<key>/source`, mirroring `getReferralUploadDocumentPath`, `db/referrals.ts:752-763`); one `referral_extract_versions` row (version 1 = current extract) for every referral at `extracted`+.

Flow changes:

- **Amendment upload:** new `POST /api/v1/referrals/[id]/documents` (guard `referral:ingest`): stores Blob at `referrals/uploads/<referral-id>/amendments/<uuid>`, inserts a `referral_documents` row with `doc_set_version = max + 1`, appends an event. It does **not** auto-re-extract.
- **Deliberate re-extraction** (`sr-plan.md:37` "deliberate re-extraction"): explicit `POST /api/v1/referrals/[id]/re-extract` enqueues the existing `referral.extract` job kind with the full active document set (the WS-2 funnel already accepts multiple documents — `extractReferral()` takes an input array, `src/lib/ingestion/extract.ts`). On completion, `attachExtractToReferral` (extended) snapshots the outgoing extract into `referral_extract_versions`, bumps `referrals.extract_version`, and evaluation re-queues as today — producing a fresh `evaluation_runs` row (the LEFT JOIN LATERAL latest-run pattern in `db/referrals.ts:150-174` picks it up automatically).
- **Field-level diff:** `src/lib/referrals/extract-diff.ts` — pure deterministic diff of two `ReferralExtract` values over canonical paths → `{ path, before, after, kind: added|removed|changed }[]`. No AI. Used by the Evidence documents panel and the stale-decision inline diff.
- **Supersession/contradiction states:** derived per document (`superseded_by` set when a newer doc explicitly replaces one) and per field (diff between versions where an older verified value conflicts with a new extract value ⇒ "contradiction" chip in the Evidence pane; the old field review no longer applies because its `extract_version` is stale — the human re-verifies, which *is* the reconciliation act).
- **Implementation caution:** the amendment/re-extract path regresses `referrals.status` to `extracted → evaluating → …` by design (the row is being re-processed). Decision presence is carried by `referral_decisions`, not status, so the workspace header keeps showing "Decision recorded (now stale)". Queue presentation for amended-and-decided rows must be covered by a fixture + test (§6.2 `amended_after_decision`).

### 4.3 `0012_charge_out_rate_cards.sql` — admin-editable flat rates

```sql
CREATE TABLE IF NOT EXISTS charge_out_rate_cards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version INT NOT NULL UNIQUE,
  rates JSONB NOT NULL,                  -- {"hca": 3200, "rmn": 6500} pence/hour
  label TEXT,
  status TEXT NOT NULL CHECK (status IN ('active','retired')),
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_rate_cards_one_active
  ON charge_out_rate_cards (status) WHERE status = 'active';
-- seed: version 1, {"hca":3200,"rmn":6500}, status 'active', created_by 'seed:sr-plan-4b'
```

Editing = insert new version + flip statuses in one transaction (`retired` rows keep history; decisions snapshot lines anyway so nothing depends on history for correctness). Role-keyed JSONB keeps the door open for more roles without DDL; zod contract (`src/lib/contracts/rate-card.ts`) validates known role codes. Editor UI on Settings, guard `rates:manage`.

### 4.4 Criteria changes — `migrations/0003_criteria_rationale.sql` + corpus v2 (TDDI, solo re-scope)

The criteria set lives in the *other* migration directory (`migrations/`, `schema_migrations` tracking — `scripts/db/migrate.mjs:28-33`).

- `ALTER TABLE criteria_rules ADD COLUMN IF NOT EXISTS rationale TEXT;` — the "recorded rationale" home for captain decision 2 (agent survey confirmed no such column exists today; `migrations/0001:10-30`).
- **Corpus v2** (`src/lib/criteria/corpus.json`, `sourceVersion: "v2-draft"`):
  - Retire the 7 `ofsted-*` rules via `effective_to` (rows kept; seed script upserts by id — `scripts/db/seed-criteria.mjs:45-54` — so retirement is a data update, reversible by nulling `effective_to`).
  - Re-scope `cqc-compatibility-matching-1`: new rule text acknowledging solo one-bed settings satisfy peer-compatibility structurally (no existing resident group), while environment/staffing/tenancy compatibility evidence still applies; `rationale` column carries the captain-decision-2 wording ("peer co-placement risk is structurally absent in solo one-bed settings; not an auto-pass; environment/staffing/tenancy compatibility still assessed").
  - Add TDDI-basis citations for children under complex care (discovery + clinical lead to confirm exact instruments; rows stay `draft_unverified` — the `status` flip remains the clinical lead's act, `src/lib/contracts/criteria.ts:20-23`).
- **Additive contract field:** `gateResultSchema` gains optional `criteriaRuleId?: string` (`src/lib/contracts/gates.ts:45-55`). Today `resolve.ts:74-89` consumes the model's `ruleId` to fetch the citation and then discards it, so the per-gate review UI cannot show *which rule* grounded a gate. Keeping the id is additive (optional field; old persisted gates parse unchanged) and makes the criteria review UI honest. `resolveGates` copies the id onto surviving pass/fail/conditional gates.
- **Criteria currency indicator:** the review UI re-runs `retrieveCriteria(regime, placementType)` at render and compares `criteriaRulesetVersion()` (`src/lib/evaluation/engine.ts:82-100`) against the stored `evaluation_runs.criteria_version`. Mismatch ⇒ "criteria updated since this evaluation" chip (honest display; historical rule text is not reproducible today because the seed upserts in place — noted as risk R6).

### 4.5 `0014_referral_decisions.sql` — append-only decisions + approvals

```sql
CREATE TABLE IF NOT EXISTS referral_decisions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_id UUID NOT NULL REFERENCES referrals (id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('accept','accept_conditional','decline','refer_on')),
  rationale TEXT,                        -- required by app rules when diverging/no advisory (mirrors actions.ts:60-66)
  decided_by TEXT NOT NULL,
  decided_by_role TEXT NOT NULL,
  risk_classes TEXT[] NOT NULL DEFAULT '{}',      -- ('decline','crisis','safety_signal','low_evidence')
  requires_second_approval BOOLEAN NOT NULL,
  supersedes_decision_id UUID REFERENCES referral_decisions (id),
  -- visible binding (sr-plan.md:24): versions + priced basis snapshot
  extract_version INT NOT NULL,
  criteria_version TEXT,
  rate_card_version INT,
  evaluation_run_id UUID,
  gate_resolutions JSONB NOT NULL DEFAULT '[]',   -- [{gate, resolution: confirm|override, note?}]
  pricing_snapshot JSONB,                          -- FlatPriceResult lines + total + formula
  provision_label TEXT,
  fee_weekly_pence INT,
  advisory_decision TEXT,                          -- what presentRecommendation showed (null when none)
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- append-only triggers (audit_log pattern)

CREATE TABLE IF NOT EXISTS referral_decision_approvals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_id UUID NOT NULL REFERENCES referral_decisions (id) ON DELETE CASCADE,
  approver_id TEXT NOT NULL,
  approver_role TEXT NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- append-only triggers; app-layer rule approver_id != decided_by (unit-tested)
```

Domain library `src/lib/referrals/decisions.ts` (pure) + `src/lib/db/decisions.ts`:

- **Currency is derived, never stored:** `deriveDecisionState(rows, approvals, referral) → { current, status: confirmed|awaiting_second_approval|superseded|invalidated_by_amendment }`. Current = latest non-superseded row; invalidated when `extract_version < referrals.extract_version`.
- **Risk classes** computed server-side at confirm time: `decline` (kind), `crisis` (effective `metadata.urgency ∈ {crisis, same_day}`), `safety_signal` (prompt-injection flag per `src/lib/ai/safety-signals.ts` reason codes on the evaluation run, or risk-behaviour markers per criticality registry), `low_evidence` (quality panel evidence coverage below threshold). Non-empty ⇒ `requires_second_approval = true` (`sr-plan.md:24` — risk class, not service line).
- **Neutral review/confirm invariants** (enforced in the server action, mirrored from the legacy action so both paths share rules): nothing preselected ever; rationale required when there is no trustworthy advisory or when the human diverges from it (`presentRecommendation().advisoryDecision` — same funnel as `src/lib/referrals/actions.ts:53-66`); every criticality-registry field must be verified/corrected/marked-missing; every critical/unassessed gate must carry an explicit resolution in `gate_resolutions` (consequence-driven review, `sr-plan.md:25`).
- **Confirm transaction:** insert decision row → dual-write legacy `human_review` when legacy-compatible (A5) → content-minimised `referral_events` (`human_decision`/`recorded`, kinds + versions only) → `revalidatePath`. Audit: the recommendation itself was already audited at evaluation time via `recordRecommendationAudit` (`src/lib/jobs/pipeline.ts:718-724`); the decision row *is* the decision audit (append-only, DB-enforced).
- **Stale path:** decide route detects binding mismatch (plan changed via rate card, extract changed via amendment) → renders the inline field diff (`extract-diff.ts`) → requires "explain change" note → re-review (`sr-plan.md:24`).
- **RBAC:** guard `clinical:decide` for confirm, `clinical:decide` + distinct user for approval (see §4.7).

### 4.6 `0015_referral_la_responses.sql` + `0016_referral_dispositions.sql`

```sql
CREATE TABLE IF NOT EXISTS referral_la_responses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_id UUID NOT NULL REFERENCES referrals (id) ON DELETE CASCADE,
  decision_id UUID NOT NULL REFERENCES referral_decisions (id),
  body TEXT NOT NULL,                    -- generated draft; body rows immutable (new draft = new row)
  prepared_by TEXT NOT NULL,
  sent_state TEXT NOT NULL DEFAULT 'draft'
    CHECK (sent_state IN ('draft','copied','downloaded','marked_sent')),
  marked_sent_at TIMESTAMPTZ, marked_sent_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS referral_dispositions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_id UUID NOT NULL REFERENCES referrals (id) ON DELETE CASCADE,
  outcome TEXT NOT NULL CHECK (outcome IN ('won','lost_price','lost_capacity','withdrawn','no_response')),
  reason_code TEXT,
  notes TEXT,
  recorded_by TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

- **LA responses:** `sent_state` is operational (not clinical-audit) state, so those two columns are mutable; every transition appends a `referral_events` row, and `body` is never edited after insert (regenerate = new row). The P3 outbox will own real sending; `marked_sent` is the human's typed claim (§3 "typed sent state").
- **Workspace response builder** `src/lib/workspace/la-response.ts`: adapted from the legacy `buildLaResponseDraft` (`src/lib/referrals/la-response.ts:24-83`) but bound to the **decision row** (kind, condition, provision label, flat weekly charge, binding versions) + effective record, not the homes mock; the legacy builder's `presentRecommendation` guard behavior (stub referrals get "Response pending — no trustworthy advisory…", verified by `la-response.test.ts:40`) carries over: no response can be prepared without a confirmed decision, and the copy is generated from the *human* decision, never the advisory.
- **Dispositions:** latest row wins for display; "Record LA outcome" action available once a decision exists (response optional — LAs sometimes withdraw before we respond); appears in Timeline. Reporting is P4.

### 4.7 RBAC capability names (static derivation — no engine)

Per `sr-plan.md:34`, capability names are introduced now as a static derivation from the existing 5 roles behind the existing `can()` seam (`src/lib/auth/rbac.ts:52-54`), additive to `PERMISSIONS` (`rbac.ts:22-30`):

| New capability | viewer | reviewer | manager | admin |
|---|---|---|---|---|
| `evidence:verify` | – | ✓ | ✓ | ✓ |
| `clinical:decide` | – | ✓ | ✓ | ✓ |
| `commercial:approve` (second-person approval) | – | ✓* | ✓ | ✓ |
| `response:prepare` | – | ✓ | ✓ | ✓ |
| `rates:manage` | – | – | ✓ | ✓ |
| `source:download` (formalises the existing source-route check) | ✓ | ✓ | ✓ | ✓ |

\* Whether reviewers can second-approve (vs manager-only) is open question Q1. Distinct-user enforcement is app-layer regardless of role. The comment at `rbac.ts:21` ("Advisory tool: no 'decide' capability") is updated deliberately in PR-P2.7: the workspace decide flow records a *human* decision (Art. 22-compatible — the human decides, the tool advises); the DPIA note is updated in the same PR. Route guards keep going through `requirePermission()` (`src/lib/auth/guard.ts`) per WS-7.

---

## 5. The P1 exit study — what waits vs what builds now

P1's exit gate is the moderated task study (5–8 staff; find-next-item unaided ≥80%; source-of-truth for a critical field <30s; first actionable row at 375×812; keyboard/SR/zoom/theme/slow-network; DTO + bundle budgets — `sr-plan.md:54`). The split below lets implementation start immediately and keeps every study-sensitive surface behind a later PR:

**Safe to build now (study-independent — backend truth and binding business rules):**

1. All six migrations + contracts + db modules (§4) — the study cannot change what a field review or decision *is*, only how it is presented.
2. `effective-record.ts`, `extract-diff.ts`, decision derivation, risk classes, approvals — pure domain logic with exhaustive unit tests.
3. Rate table + flat-pricing wiring + Settings editor (§4b rule 3 is binding; no study can override it).
4. Criteria corpus v2 + TDDI/solo re-scope + engine repoint (§2.1, §4.4) — captain-ordered; rule *content* needs captain/clinical text review, not the study.
5. Amendment upload + re-extract mechanics.
6. RBAC capabilities; DTO/leak-test extensions; fixture archetypes; CI bundle-budget check.
7. LA response generation logic and disposition records (copy templates reviewable async by the RM/copy-governance owner, `sr-plan.md:45`).

**Study-informed remainder (interaction design — build after findings, or build with the stated defaults and fold findings into a follow-up within the same milestone):**

1. **Verification interaction** — the study's "<30s source-of-truth" task directly probes this. Default proposal: inline per-row actions in the Record pane (Verify one-click; Correct opens a small sheet with value + reason; Mark-missing one-click with reason picker), matching S8's overlay-wholesale row (`sr-plan.md:23`).
2. **Evidence default-tab rule** — state-aware landing (needs_review/low coverage/contradictions → Evidence; clean → Overview, `sr-plan.md:22`). P1 defaults to Overview always (`referrals/[id]/page.tsx:91-93`); flip to state-aware only after observing where users actually go first.
3. **Bidirectional source↔field highlighting depth** (`sr-plan.md:23`) — core provenance links (field → documentId/page/quote from `sources[]`, `contracts/common.ts:54-66`) are safe-now; interactive highlight-on-click both ways is polish that should follow observed reading patterns.
4. **Decide-route layout** — the stable routes review → correct → confirm (`sr-plan.md:49`) map naturally onto detail tabs (review) → Evidence (correct) → `/decide` (confirm). Whether `/decide` is one page with a readiness checklist or a two-step page is study-informed; the domain rules beneath do not move.
5. **Criticality registry contents** — which fields staff *actually* treat as decision-critical; seed from P1's eight paths (quality-panel.ts:38-47) and adjust with RM sign-off.
6. **Assessment per-gate review presentation** and how gate-resolution capture feels (checkbox vs per-gate confirm) — the plan's own tension ("no seven-click theatre", `sr-plan.md:25`) is empirically resolvable.
7. **Staffing shift view** (A6) — build only if demanded.
8. My-work bucket set for decision states; queue decision chips.

If the study slips, the stated defaults ship behind the cohort flag and findings land as a follow-up PR — the pilot cohort (`WORKSPACE_V2_COHORT`) bounds the blast radius.

---

## 6. Testing strategy (consistent with P0's fixture matrix)

### 6.1 Layers

- **Unit (Vitest, jsdom, colocated `__tests__`)**: effective-record merge precedence (per-action, latest-wins, stale-version exclusion); extract diff determinism; decision currency derivation incl. supersession chains + amendment invalidation; risk-class computation; distinct-approver rule; flat pricing from rate card incl. fallback-to-constants; TDDI review-reason predicate; criteria v2 gate coverage (`assertDecisionGateCoverage` still passes with ofsted retired — `repository.ts:94-111`); RBAC derivation table.
- **Contract/leak tests**: extend `QUEUE_DTO_FORBIDDEN_KEYS` + `findForbiddenQueueDtoKey` recursion (queue-dto.ts:26-38, :263-288) for the new content-bearing keys; new decision/field-review DTOs get their own leak tests (a decision list row may carry kinds/versions/fee, never `rationale`, `corrected_value`, `reason`, extract bodies).
- **Component tests** (Testing Library): verification row states; confirm sheet renders bindings; nothing-preselected assertions on the decide route (extending the pattern of `review-form.test.tsx:27`).
- **E2E (Playwright, pilot session seam)**: new `e2e/workspace-p2.spec.ts` — verification round-trip; decide happy path with visible binding; stale-binding diff path (amend → decide blocked → explain); rates edit → price updates + version chip; LA response prepare/copy; 375×812 decide flow; keyboard-only verification pass. The existing `workspace-p1.spec.ts:71-75` assertion (no on-cost/absence/property lines) stays green throughout — it is the §4b rule 3 sentinel.
- **DB-level checks (manual, per-PR checklist)**: append-only triggers reject UPDATE/DELETE (SQL run on a Neon branch — unit tests mock `query`, so trigger behavior can't be asserted in Vitest; keep this honest in the PR template); migration idempotency (`npm run db:migrate` twice → second run all `skip`).
- **BRB real-user QA**: every UI-bearing PR ends with a BRB pass on the running app (per the task's definition of done), results filed under `docs/qa/runs/` like `COORDINATOR-MERGE-2026-07-13-p1.md`.

### 6.2 Fixture matrix extensions (`src/lib/referrals/fixtures/matrix.ts` + `fixtures-bridge.ts`)

Keep all 8 existing archetypes; **`indeterminate_stub` (`fixture-screenshot-14`, matrix.ts:290-304) is frozen as the regression anchor.** Add:

| New archetype | Purpose |
|---|---|
| `child_tddi` | age < 18, regime cqc, evaluates in scope, carries `tddi_criteria_draft` review reason until rules approved — the §4b rule-1 sentinel |
| `verified_ready` | all criticality-registry fields verified/corrected — decide route unblocked |
| `amended_after_decision` | decision row bound to extract_version 1, referral at extract_version 2 — exercises derived invalidation + stale diff |
| `decided_awaiting_second` | decline decision with `requires_second_approval` and no approval row |
| `decline_second_approved` | full two-person decline — reporting-safe example |

`out_of_scope` stays as-is (already non-Ofsted, matrix.ts:367-369 comment) and gains the manual refer-on decision in its expected flow.

### 6.3 Screenshot-14 regression, extended to every new surface

The P0 stub (`src/lib/referrals/__tests__/fixtures/screenshot-14-stub.ts`: decision accept, confidence 0, all gates not_assessed) currently guards presentation (`fixtures-matrix.test.ts:24`, `present-recommendation.test.ts:149`, detail/queue/badges/dto/la-response tests). P2 adds, for the same fixture:

1. Decide route: renders "No recommendation", **nothing preselected**, rationale required (the `advisoryDecision == null ⇒ notes` rule), and the confirm records `advisory_decision = null`.
2. Assessment tab: gates shown as not-scored-advice (existing copy, `referrals/[id]/page.tsx:301-306`), every gate demanding explicit resolution before confirm.
3. Quality panel: `trustworthyAdvice === false` keeps the decide route in evidence-first mode.
4. Workspace LA response builder: refuses accept-flavoured copy without a confirmed human decision (extends `la-response.test.ts:40` to the new builder).
5. Queue/My-work: unchanged "No recommendation" chip with a decision-state chip only after a human decision row exists.

### 6.4 CI bundle budgets (catch-up item)

`sr-plan.md:39` sets budgets (<170KB inbox, <230KB evidence workspace, gz) and the P1 exit gate says "budgets met", but no CI check exists in the tree (verified: no budget script/workflow). PR-P2.2 adds a `next build`-output budget script wired into CI so the evidence workspace (which P2 grows the most) is measured from the start; first run records the baseline, then enforces.

---

## 7. Milestones — single-PR increments with acceptance criteria

Ordering rationale: data cores first (safe-now, unblock everything), engine repoint early (captain-binding, low-UI), decision flow after verification + criteria + amendments exist (its readiness rules consume all three), response/disposition last (consume decisions). Sizes: S ≈ ≤400 LoC, M ≈ ≤1000, L ≈ >1000 (net, excl. tests).

| PR | Contents | Size | Study-gated? |
|---|---|---|---|
| **P2.1 Field-review data core** | Migration 0011; `contracts/field-review.ts`; `effective-record.ts`; `criticality.ts` registry (quality panel re-pointed); `db/field-reviews.ts`; leak-test extensions. No UI. | M | No |
| **P2.2 Evidence verification UI** | Server actions (`evidence:verify`); Action pane → real Verify/Correct/Mark-missing; Record pane effective-record chips + provenance links; contradiction chip; DPIA note; CI bundle-budget script. | L | Defaults now; polish folds in findings |
| **P2.3 Rate table + price decomposition** | Migration 0012 + seed; `contracts/rate-card.ts`; `db/rate-cards.ts`; `flat-pricing` wiring + version display; Settings rates editor (`rates:manage`); Staffing tab decomposition reads *effective* ratio. | M | No (§4b-binding) |
| **P2.4 Criteria v2 + TDDI engine repoint** | `migrations/0003` rationale column; corpus v2 (ofsted retirement, solo compatibility re-scope + rationale, TDDI citations); extraction prompt tweak; remove regime-based routing (engine.ts:329-334, pipeline.ts:695-703); `tddi_criteria_draft` transitional reason; optional `criteriaRuleId` on gates; fixtures `child_tddi`. No UI. | M | No (captain-binding; rule text needs captain/clinical review, not the study) |
| **P2.5 Assessment per-gate criteria review UI** | Per-gate rule text/citation/rule-id display; criteria-currency chip; gate-resolution capture (client state → decide); evidence links per gate. | M | Yes — presentation |
| **P2.6 Documents + amendments** | Migration 0013 + backfills; documents API + amendment upload; deliberate re-extract endpoint + pipeline extension (extract-version snapshot/bump); `extract-diff.ts`; Evidence documents list + diff view; source route by document id; `amended_after_decision` fixture. | L | Mechanics no; diff-view presentation yes |
| **P2.7 Append-only decisions + decide route** | Migration 0014; `contracts/decision.ts`; `db/decisions.ts` + derivation lib; RBAC capabilities; `/decide` stable route (readiness checks, neutral confirm, visible binding, stale inline diff, explicit Cancel); dual-write legacy `human_review`; events; screenshot-14 decide tests. | L | Domain no; route layout yes |
| **P2.8 Second approval + queue/My-work decision states** | Approvals UI (distinct-user); awaiting-approval bucket; queue decision-state scalars in CTE/DTO + leak tests; `decided_awaiting_second` fixtures. | M | Light |
| **P2.9 LA response prep** | Migration 0015; workspace response builder (decision-bound); prepare/copy/download + typed sent state + events; RM copy review. | M | Copy tone RM-reviewed; layout light |
| **P2.10 Disposition skeleton** | Migration 0016; record-outcome action + Timeline entry; contracts. | S | No |

**Acceptance criteria common to every PR:** `npm run typecheck`, `npm run lint`, `npm test`, `npm run test:e2e` green; migrations applied twice on a Neon branch (second run all `skip`); append-only triggers verified by SQL where introduced; screenshot-14 suite green; DTO leak tests green; no changes to `CONTRACT_VERSION`, `DECISION_GATES`, `regimeSchema`, or `rank.ts` policy version; **BRB real-user QA pass on the running app for every PR with UI** (P2.2, 2.3, 2.5–2.10), filed under `docs/qa/runs/`.

**Per-PR spot checks (selected):**
- P2.2: verify → chip flips to verified with actor/time; correct → effective value everywhere (Overview, Staffing ratio, quality panel) while raw extract remains visible as provenance; no `reason`/`corrected_value` in any event/log line.
- P2.3: editing rates changes new price displays + version chip; existing decisions' snapshots unchanged; empty table ⇒ constants fallback labelled.
- P2.4: ofsted-tagged extracts no longer forced to outside-service-line review; child fixture evaluates + prices + carries `tddi_criteria_draft`; `assertDecisionGateCoverage` passes with the ofsted rows retired; the legacy `(app)` detail surface is left untouched (its banner disappears at cutover, not in P2).
- P2.7: no preselection anywhere; confirm blocked until criticality fields resolved + critical/unassessed gates resolved; binding sheet shows extract/criteria/rate-card versions + provision + fee; divergence-requires-rationale matches legacy behavior; decline auto-sets `requires_second_approval`.

Estimated wall-clock: 3–5 weeks at F3 pace with the safe-now PRs (P2.1, 2.3, 2.4, 2.6 mechanics) parallelisable across two lanes while the study runs.

---

## 8. Open questions / risks

### Open questions (need captain / clinical input; none block P2.1–P2.4)

| # | Question | Recommendation |
|---|---|---|
| Q1 | **Second-approval enforcement during the pilot** — with a cohort that may have one reviewer, a hard block on decline/crisis makes referrals unconfirmable. Also: can reviewers second-approve, or manager+? | Enforce from day one for `decline` + `safety_signal`; approvals queue as `awaiting_second_approval` rather than blocking the decider; any distinct `clinical:decide` holder may approve; env off-switch documented for single-reviewer pilot only |
| Q2 | **The refused-work list** (what is "genuinely out-of-scope" post-4b: fostering? residential school? pure accommodation?) | Manual refer-on only in P2 (A8); captain supplies the list before any automatic classification |
| Q3 | **TDDI basis confirmation** — the plan assumes TDDI = CQC regulated activity "Treatment of Disease, Disorder or Injury"; discovery must record the exact instruments/citations for children under complex care | PR-P2.4 rule text drafted for captain/clinical review; rows stay `draft_unverified` until sign-off; `tddi_criteria_draft` review reason until then |
| Q4 | **Does P2 include envelope multi-file intake?** (A1) | No — amendment-only; data model accommodates envelope later |
| Q5 | **Workspace pricing overrides beyond the record** — does a reviewer ever need to price a different ratio than the (effective) record states? Legacy working-plan/chat ops support this; workspace P2 prices from the effective record only | Wait for the study; if needed, expose a constrained override on the decide route that itself becomes part of the decision snapshot — never resurrect on-cost/absence/property inputs |
| Q6 | **Rate card roles beyond HCA/RMN** — §4b names two; the role vocabulary has five (`roles.ts:11-17`) | Seed only hca/rmn; JSONB rates map accepts more without DDL when the captain adds them |
| Q7 | **Study timing vs P2.2/2.5/2.7** | Proceed with stated defaults behind the cohort flag; fold findings as follow-ups within each milestone |

### Risks

| # | Risk | Mitigation |
|---|---|---|
| R1 | Append-only + derived currency is subtle (supersession chains, amendment races) | Pure derivation library with property-style unit tests; `FOR UPDATE OF r` transaction pattern already exists (`db/referrals.ts:473-484`, `actions.ts:41-42`); fixtures for every derived state |
| R2 | Dual-write divergence between `referral_decisions` and legacy `human_review` | Single transaction; reconciliation unit test (same inputs ⇒ consistent presentations via `presentRecommendation`); documented gap for non-legacy-compatible statuses (A5) |
| R3 | TDDI repoint changes legacy-engine behavior for children referrals (previously forced review) before children-specific criteria are approved | Transitional `tddi_criteria_draft` review reason keeps every child referral in human review until clinical sign-off; fixture sentinel |
| R4 | Amendment re-extract regresses lifecycle status on decided referrals; queue/detail could momentarily misrepresent | Decision presence derived from `referral_decisions`, not status; `amended_after_decision` fixture + queue test; timeline event explains the regression |
| R5 | Field corrections could be mistaken for changing the source of truth (clinical-governance concern) | Extract never mutated; UI always shows extracted value + correction side by side with actor/reason; DPIA updated; append-only DB triggers |
| R6 | Criteria seed upserts in place (`seed-criteria.mjs:45-54`) — historical rule text is not reproducible, so the review UI can only show *current* rules + a version-mismatch chip | Honest currency chip in P2; move to strictly versioned rule rows (supersede-not-update) as part of the pre-P5 criteria workstream |
| R7 | Pricing snapshot drift (rate edits mid-decide) | Decision confirm re-validates rate-card version and re-prices server-side inside the transaction; mismatch ⇒ stale path, same as extract staleness |
| R8 | Scope creep from the intake row (envelope, quarantine, malware scan) | A1 boundary; intake security hardening beyond current upload guards is explicitly not P2 |
| R9 | Two planners diverging (this draft vs the parallel one) | Cross-review round is planned by firstmate; §1.1 ambiguity log gives explicit merge points |

---

## 9. Rejected alternatives

| Alternative | Why rejected |
|---|---|
| Mutate `referrals.extract` in place for corrections | Plan §2 field-verification row mandates overlay + "extract never mutated"; destroys provenance and the inspection artefact |
| Store field reviews in a JSONB column on `referrals` | No DB-enforced append-only, concurrent-writer hazards, no per-review actor/version audit; the audit-trigger pattern needs a table |
| Reuse `referral_working_plans` as the flat-pricing store (neutralise on-cost/absence to 1/0) | Entangles §4b pricing with legacy draft machinery + 10 chat ops built for the pay-cost model; flat pricing is a pure derivation (ratio × table) — a durable draft adds a second source of truth for the same number; decisions snapshot the priced basis instead. Revisit only if Q5 proves override demand |
| New standalone `workspace_pricing_plans` table | Same duplication problem without the legacy-compat benefit; nothing to persist that the decision snapshot + rate card don't already capture |
| Change `regimeSchema` / delete Ofsted contract values now | Frozen contracts during the rebuild (`sr-plan.md:15`, CLAUDE.md); behavior repoint achieves §4b rule 1; contract v2 (`sr-plan.md:11`, `:32`) is the coordinated vehicle |
| Hard-delete the 7 Ofsted corpus rules and the children's WTE library | Retirement via `effective_to` is reversible and auditable; the WTE library is unwired and harmless — deleting it buys nothing and loses P3 capacity groundwork |
| Mutable `status` column on `referral_decisions` (confirmed/superseded/invalidated) | Violates append-only; derived currency from bindings + supersession pointers matches the plan's derivation-constrained philosophy (`sr-plan.md:27`) and can't drift |
| A separate `referral_gate_reviews` append-only table for gate resolutions | Gate resolution is meaningful only as part of a decision act (`sr-plan.md:25` "for EVERY decision"); storing it in `referral_decisions.gate_resolutions` keeps the confirm atomic. Split later only if standalone gate review (pre-decision) proves to be a real workflow |
| Second-person approval bypass for admins | The risk-class control is the point (automation-bias defence); pilot posture handled by Q1's env switch, not a role bypass |
| AI-generated amendment diffs | Deterministic field-level diff of extract versions is auditable and free; AI only re-extracts |
| Client-side or model-side pricing arithmetic | House rule: never trust the model for headcount/£ (CLAUDE.md commercial core); server recomputes at render and at confirm |
| Building the work-item lifecycle early to host decision states | P3 scope (`sr-plan.md:56`); decision states derive cleanly from decision/approval rows without a stage machine |
| Modal/gesture-dismiss confirm sheet | Motion row (`sr-plan.md:36`): decisions are stable routes with explicit Cancel |

---

## 10. Evidence appendix (what I did)

- Read `/Users/leebarry/firstmate/data/sr-plan.md` in full (all citations by line above).
- Switched worktree to `fm/sr-p1`, then re-based on merged main after PR 24 landed mid-scout; verified `git diff origin/fm/sr-p1 origin/main` is empty.
- Read in full: all `src/lib/workspace/*` modules; workspace pages incl. `referrals/[id]/page.tsx` (444 lines); `evidence-panes.tsx`; `features/workspace.ts`; `db/referrals.ts` (960 lines incl. the queue CTE); `db/working-plans.ts`; `contracts/{common,referral-extract,recommendation,gates,working-plan}.ts`; `commercial/{roles,constants}.ts`; `referrals/{actions,service-line,evaluation-run}.ts`; migrations `0005/0006/0008/0009`, `migrations/0002_audit_log.sql`; `scripts/db/migrate.mjs`; pipeline evaluate stage (`jobs/pipeline.ts:470-775`); `auth/rbac.ts`; upload route guards; README Runtime Surface.
- Delegated two read-only surveys (criteria/evaluation/staffing; legacy UI/la-response/fixtures/tests/clearline/review-chat) — their file:line findings are incorporated above (corpus 7+7 rule split, `resolve.ts` ruleId discard, `GateResult` field names, fixture archetype inventory, e2e/test coverage of screenshot-14, 10 chat op kinds, absence of any visual-regression harness or bundle-budget CI).
- `npm run typecheck` on merged main: **pass** (exit 0).

**Recommended next step:** cross-review against the parallel draft, then start PR-P2.1 and PR-P2.4 immediately (both study-independent; P2.4 needs captain/clinical review of rule text in-flight).
