# Cross-review critique: S8 review of F3

## Executive resolution

F3 is an excellent independent audit with a sharper discovery of one critical safety defect, useful interaction-level detail, and a practical first-pass roadmap. Its best contribution is the evidence that an evaluation failure/indeterminate outcome is rendered as a green **Accept** and preselected for the reviewer in [F3 screenshot 14](/Users/leebarry/firstmate/data/sr-plan-f3/screenshots/14-referral-accept-testla.png). That should be promoted from a redesign acceptance criterion to an immediate safety fix.

For convergence, use S8's product and architecture backbone—an evidence-reconciliation workspace at a distinct `/workspace/**` route, an explicit `ServiceLine` domain separate from regulatory regime and placement type, versioned work items/decisions/capacity observations, and line-specific capacity adapters—then import F3's strongest operational details: duplicate handling, multi-document intake, outcome/clock-pause states, formula-level commercial transparency, the zero-confidence fixture, and several quick performance fixes.

Do **not** adopt F3's proposed parallel `(app)` and `(next)` trees at identical URL paths, placement-type-as-service-line model, universal solo-property schema, confidence-driven reduction in human oversight, automatic compatibility pass, or gesture-dismissable decision sheet. The first is technically invalid in the App Router; the others encode unsafe product assumptions.

The most important issue both plans missed is structural, not visual: the system persists and audits a synthetic `accept` recommendation even when evaluation failed and `requiresHumanReview` is true. Hiding the badge fixes the immediate interface hazard, but not analytics, audit semantics, exports or downstream consumers. The converged plan must add a durable evaluation-run/outcome state and exclude indeterminate stubs from recommendation statistics, while preserving the frozen contract during the UI rebuild.

## 1. Strongest ideas from F3 to adopt

### 1.1 Treat the zero-confidence “Accept” as a release-blocking safety defect

F3 found the clearest concrete failure in either audit. [The screenshot](/Users/leebarry/firstmate/data/sr-plan-f3/screenshots/14-referral-accept-testla.png) shows all of the following at once:

- evaluation says there is insufficient information;
- confidence is 0%;
- every gate is `not_assessed`;
- the recommendation badge is green “Accept”;
- the human decision input defaults to “Accept”.

This is not merely poor hierarchy. It converts an internal schema fallback into apparent advice and makes agreement the path of least resistance. Adopt F3's “No recommendation—insufficient information” state and its dedicated fixture, but go further: ship a legacy-UI hotfix before the rebuild, remove decision preselection for every outcome, add queue/detail/form/report tests, and persist indeterminate evaluation status as described in section 3.1.

### 1.2 Add duplicate-aware, multi-document intake

F3 correctly connects repeated queue rows in [F3 screenshot 03](/Users/leebarry/firstmate/data/sr-plan-f3/screenshots/03-queue-desktop.png) to an upload fingerprint the UI does not expose. Its proposed multi-file envelope also matches real LA referral packs better than the current one-file form.

Adopt:

- one intake envelope containing email body plus all attachments;
- per-document upload state and provenance;
- permission-scoped “possible duplicate” warnings;
- a compare action before any merge or closure;
- an explicit “continue as a separate referral” reason.

Do not automatically group or merge on hash alone: forwarded email wrappers, amended documents and deliberately repeated referrals can share content. Duplicate visibility must not reveal a referral outside the viewer's service/geography scope.

### 1.3 Add business outcomes and auditable SLA pauses

F3's journey includes “waiting on LA”, a paused clock, won/lost/withdrawn, and placement handover. S8 carried the workflow through response preparation/sent state but did not fully model disposition and handover. Adopt the business lifecycle, not just the labels:

- `awaiting_information` work item with pause reason, actor, start/end and policy basis;
- `response_prepared`, `response_sent` and channel/reference metadata;
- LA outcome `accepted_offer | rejected_offer | withdrawn | no_response | superseded`;
- handover record linking the referral to a placement, tenancy or domiciliary start plan.

These belong in typed, versioned business records; an untyped event should remain the audit trail, not the sole source of current truth.

### 1.4 Adopt F3's immediate engineering quick wins

F3 found several small, independent improvements that should be pulled into Phase 0:

- unify the engine's configurable 0.65 review threshold and the hard-coded 0.6 fallback in `src/lib/jobs/evaluate.ts:118`;
- request-cache the authenticated session within one server render;
- add route and client file-size/count limits with clear failure messages;
- parallelise independent detail reads;
- add a zero-confidence/indeterminate fixture and visual regression state;
- replace the silent 50-row ceiling with cursor pagination.

Use React request memoisation only. Reject F3's optional cross-request short-TTL cache keyed by a cookie hash: role changes, revocation and session expiry should not be delayed for a small latency win.

### 1.5 Preserve the commercial decomposition and line-specific plan views

F3's staffing/price screen is more concrete than S8's in two helpful ways: it turns concurrent provision into a day/night shift view and makes every weekly price line expand to its deterministic formula. Adopt both. The working-plan experience should show:

- source-backed staffing assumptions;
- shift/time-band coverage rather than a single “2 HCA” number;
- staff cost, on-cost, absence, property and other inputs as separate lines;
- incomplete inputs as blockers/warnings, not co-equal hero metrics;
- an explicit diff when chat or a reviewer changes plan version.

Keep money in the normal sans face with tabular numerals; reserve monospace for identifiers and technical audit values. A full column of monospaced prices makes a regulated commercial interface look like debug output.

### 1.6 Use optical state differences and evidence-engagement telemetry carefully

F3's “Draft / Reviewable / Resolved” concept is a strong trust pattern: generated content and human-confirmed truth should not have the same visual composure. Adopt the principle with less ambiguous labels:

- `Processing`—no advice exists;
- `Human review required`—generated assessment is available but unresolved;
- `Human decided`—named actor, time and bound versions visible;
- `Superseded`—a newer extract, plan or decision exists.

Also adopt an authorised source-access event, but record only referral/document id, actor, time and action. Do not imply that opening a document proves meaningful review, and do not log quotes, search terms or viewport behaviour.

### 1.7 Retain F3's fixture and quality-gate discipline

The proposed fixture set—accept, conditional, decline, Ofsted/out-of-scope, indeterminate stub, evaluation failure—is a strong minimum. Expand it with:

- duplicate candidates;
- an amended/superseding pack;
- contradictory sources;
- stale capacity;
- a decision conflict/stale plan version;
- each business line's characteristic referral shape.

F3's visual matrix across 375/768/1440 and light/dark, plus axe automation, is worth adopting. S8's additional manual gates—screen-reader task completion, 400% zoom/reflow, slow network, keyboard-only review and source-document accessibility—must remain because automated axe checks are insufficient.

## 2. Concrete disagreements with F3

### 2.1 The same-URL `(app)` / `(next)` route-group strategy cannot work

F3 proposes `src/app/(app)/referrals/page.tsx` and `src/app/(next)/referrals/page.tsx`, selected by `proxy.ts`, while claiming both retain `/referrals`. Route groups are removed from the URL, so those files resolve to the same route and produce a build-time conflict. The current Next.js documentation states this explicitly in its [route-group caveats](https://nextjs.org/docs/app/api-reference/file-conventions/route-groups#caveats).

**Resolution:** build `/workspace/[serviceLine]/**` as the independently addressable v2 tree behind a server-side cohort flag, as S8 recommends. During pilot, flagged navigation links enter `/workspace`; old URLs stay untouched. At cutover, redirect old canonical routes to their workspace equivalents. If identical public URLs during the pilot become a hard requirement, proxy-rewrite them to a uniquely routed internal prefix such as `/__workspace/**`; do not create conflicting filesystem routes.

### 2.2 `placementType` is not Muve's service-line model

F3 says all three business lines can be discriminated by `placementType`, requiring no new service-line concept. That is too weak. `regime` answers which regulator/ruleset applies. `placementType` describes the requested delivery/setting extracted from a source and can be missing, low-confidence or “other”. Muve's operating line determines ownership, workflow, commercial adapter, capacity source, permissions and reporting. Complex care can also be delivered in a person's own home or a supported-living setting; it is not simply the complement of `supported_living` and `domiciliary` placement types.

The present code already demonstrates the confusion: `src/lib/referrals/service-line.ts` calls `regime === cqc` an active “service line”. Reusing a second imperfect proxy would deepen it.

**Resolution:** introduce `ServiceLine = complex_care | supported_living | domiciliary_care` outside the frozen WS-0 contract first, with triage confirmation and a suggested value derived from the extract. Keep `Regime` and `PlacementType` orthogonal. A later coordinated contract version may add service line to the canonical record after discovery.

### 2.3 Do not universalise the asserted solo-property model

F3 says the captain confirmed that Muve uses one-bedroom solo settings and therefore proposes a property table with binary occupancy. That is useful current-operating-model context, but it is not safe as the universal data model for all three lines:

- domiciliary care is delivered in the person's home and has no provider-property occupancy;
- supported living requires a legal separation between accommodation/tenancy and regulated care and may contain household/shared-support constraints even if Muve currently favours solo settings;
- complex care is an acuity/support characteristic, not necessarily a property type;
- a two-bedroom person-plus-staff setting still needs readiness, staffing and tenancy semantics, not merely `occupied`.

**Resolution:** use a `Capacity & Matching` product with typed line adapters. Add a `Properties` lens for the business units that operate properties, configured for today's solo inventory, but store property, tenancy, readiness, capacity observations and commitments separately. Every capacity value needs source, owner, as-of time and expiry. Do not ship F3's `properties(... readiness jsonb ...)` row as the operational source of truth.

### 2.4 Do not auto-pass compatibility for a solo setting

F3 proposes automatically passing `compatibility_matching` when `soloVsGroup === solo`. Solo removes peer co-placement risk; it does not remove person-environment, neighbourhood, staffing-team, communication, trauma, landlord/tenancy, safeguarding-geography or community compatibility. `soloVsGroup` is itself AI-extracted and may be missing or wrong. An automatic pass would turn one uncertain field into a regulatory conclusion.

**Resolution:** keep all seven frozen gates during the rebuild. Author approved line-scoped criteria that reinterpret the evidence required per line. Where a gate is genuinely inapplicable, record that explicitly only after the contract has an approved `not_applicable` semantic; do not disguise inapplicability as `pass`. A future contract-v2 decision can introduce per-line gate applicability after real supported-living and domiciliary pilots.

### 2.5 Out-of-scope referrals must not be demoted to the bottom

F3 proposes demoting Ofsted/out-of-scope rows to the bottom of every queue view. An outside-service-line child or safeguarding referral may still require the fastest human handoff. “Not ours” changes the action, not necessarily the urgency.

**Resolution:** route these referrals to a visible `Intake exceptions / refer-on` lane with an owner, SLA and auditable disposition. Remove Muve's normal accept/decline control, but never hide or deprioritise solely because the record is outside the active service line.

### 2.6 Confidence must not determine how much checking an “Accept” receives

F3 requires per-gate verdicts for non-accept or low/unsure outcomes, but allows a single attestation for high-confidence accepts. This makes the least disruptive, model-aligned decision the easiest exactly when automation bias is strongest. Its proposed `High / Likely / Unsure / Low` bands are also derived from confidence plus review-reason count without calibration evidence; those words can be read as probabilities of correctness. Hiding the exact value in a hover tooltip fails touch and accessibility users.

**Resolution:** drive required review tasks from consequence, unresolved evidence, criteria status, risk and local policy—not model agreement. Require explicit resolution of critical/unassessed gates and material staffing/commercial assumptions for every decision; avoid seven-click theatre for already verified non-critical gates. Show confidence and review reasons as secondary metadata. Introduce verbal calibration bands only after an outcome study validates them, and never make material information hover-only.

### 2.7 The 16px SLA ring and opaque risk formula are not a safe priority model

F3's ring is visually distinctive but too small to carry due-time meaning, depends heavily on colour and hides the absolute deadline in a tooltip. “SLA remaining × urgency × acuity” is not a specified or auditable ranking formula and can produce unintuitive inversions.

**Resolution:** show visible relative and absolute due text (`Due in 2h · today 14:00`), status text/icon and a concise rank reason. Use deterministic lexicographic bands: breached contractual deadline, crisis/same-day safeguarding, due soon, then older routine work; add approved clinical escalation rules and stable received-time tie-breaking. A small ring may be a redundant decoration only. Users may sort, but the default priority rule and policy version must be inspectable.

### 2.8 Do not use a drag-dismiss sheet for the decision act

F3 applies a Vaul spring and velocity-projected drag dismissal to the mobile decision sheet. The decision is high consequence, binds a plan version and may contain reviewer input. Gesture dismissal introduces accidental closure and makes the most serious workflow feel like a transient consumer-app surface. The gate-row entrance stagger and number ticker are similarly too theatrical for evidence and price changes; they delay comparison and can obscure exact deltas.

**Resolution:** make review/confirm a stable full-screen mobile route or non-dismissible task panel with explicit Cancel/Back and preserved draft. Use sheets for reversible filters or contextual help. Retain fast press feedback, origin-aware popovers, focus continuity and reduced-motion variants. Use a brief change highlight plus old→new diff for prices, not an odometer. No stagger on evidence or gates.

### 2.9 The lifecycle spine is internally inconsistent

F3 says the UI must mirror nine implemented statuses exactly, then proposes a branded five-step spine (`Received → Extracted → Evaluated → Decided → Responded`). Those are a mix of technical pipeline states, a human-review overlay and new business outcomes. A full-width spine also repeats the current UI's mistake of giving pipeline history more visual weight than the user's task.

**Resolution:** show one compact current-state/task label in the header, an expandable technical event timeline, and a separate business workflow status from the work-item/response/decision records. Never display a percentage-like progress bar for discrete asynchronous stages. Keep the segmented brand mark only as a brand mark, not the primary information carrier.

### 2.10 The proposed list query remains coupled to raw JSONB

F3 improves `SELECT *` but suggests extracting roughly twelve list values with `jsonb_path` for every queue request. That is a reasonable bridge, not the target read architecture. Search, filtering, permissions, SLA ranking and aggregate counts across growing data will eventually depend on expression indexes and duplicated path logic.

**Resolution:** ship a narrow SQL DTO immediately, then converge on a transactionally maintained referral/work-item summary projection with typed scalar columns and stable indexes. Add a test that prevents raw extract, source quotes, notes or chat content from entering list DTOs. Use keyset pagination and database-side counts/ranking.

### 2.11 F3's assignment/SLA/property schema is too lossy

A current assignment row plus `sla_due_at` columns on `referrals` cannot represent multiple tasks, team ownership, reassignment history, separate acknowledge/review/respond deadlines, pause/resume or policy versions. Inferring “responded” from `referral_events` has the same projection problem. A single property row with JSON readiness has no source freshness or commitment ledger.

**Resolution:** prefer S8's `referral_work_items`, append-only assignment events, versioned SLA policies, `referral_decisions`, response/disposition record and typed capacity observation/commitment model. Maintain current projections for fast reads, but keep history replayable. Dual-write only where the legacy screen needs it, with reconciliation metrics.

### 2.12 Do not pre-install the entire interaction library or invent a product name

F3's shadcn/Radix choice is correct, but requiring TanStack Table, cmdk, Vaul, Motion and Recharts in Phase 0 is premature. A 25-row keyset page does not require a large client data-grid. Critical review does not need Vaul. Reports do not need Recharts before metric definitions exist. “Clearline” and a clinical-blue palette are also unapproved brand inventions.

**Resolution:** shadcn source components on Radix and Tailwind v4, adding a dependency only when a named screen needs it. Use the already-bundled Source Sans 3 as the operational face; reserve Source Serif 4 for generated reports/editorial surfaces and IBM Plex Mono for ids/audit. Keep the neutral slate foundation and one placeholder Muve-primary token until the captain supplies brand assets. CQC-domain colours may be redundant accents in reporting, never status semantics.

## 3. Gaps both drafts missed or did not carry far enough

### 3.1 Persist the difference between a recommendation and an indeterminate evaluation

Both plans focus on preventing the UI from displaying the stub. Neither makes the data/audit correction explicit enough. The current fallback constructs `decision: "accept"` on unexpected failure (`src/lib/jobs/evaluate.ts:103-113`), and the pipeline then writes that result through `recordRecommendationAudit()` and stores it as the current recommendation (`src/lib/jobs/pipeline.ts:588-606`). Review reason codes live only in event detail.

Consequences extend beyond screenshot 14: a report, export, query or future integration can count a failed evaluation as an advisory accept even after the new UI hides it.

**Add to the converged plan:** an additive `evaluation_runs`/outcome snapshot containing `state = completed | indeterminate | failed`, `requires_human_review`, reason codes, model/prompt/criteria/extract versions and the optional recommendation. Queue/report DTOs must expose `recommendation = null` when state is not completed. Keep the current `RecommendationResult` contract frozen for the UI rebuild, but schedule a coordinated v2 that represents unavailable advice without inventing an accept. Backfill existing zero-confidence/failure signatures as indeterminate and exclude them from recommendation/override metrics.

### 3.2 Model amended referral packs and source supersession

Both drafts improve initial multi-file upload, but LA referrals evolve through email replies, revised risk assessments and changed funding/start dates. Treating each arrival as a duplicate or a new referral loses the case history; silently appending documents can leave old facts active.

**Add:** a referral envelope with document-set versions; “add amendment” intake; source supersession/contradiction states; field-level diff; deliberate re-extraction/re-evaluation; reviewer choice about which correction becomes effective; and automatic invalidation of a pending decision when a material source version changes. The audit pack must show what source set the human actually reviewed.

### 3.3 Add document-ingestion and viewer security beyond prompt injection

Both plans cover prompt-injection signalling and file-size limits, but neither specifies controls for malicious or pathological files—especially recursive EML attachments, spoofed MIME types, decompression bombs or active content in a viewer.

**Add:** allowlisted type detection from bytes, file/count/total-envelope/decompression/recursion limits, quarantine and approved malware-scanning decision, filename normalisation, sandboxed viewer/CSP, no active macros/scripts, and safe failure codes. Documents remain private and unavailable to reviewers until the intake security state is clear; urgent manual handling needs a documented fallback.

### 3.4 Add equality, fairness and challenge governance

The canonical extract contains age, sex/gender, ethnicity, religion, disability/diagnosis and legal-status information. Neither roadmap includes an Equality Impact Assessment, a review of whether each characteristic is legitimately used by each gate, or a route to challenge/correct a materially wrong advisory assessment.

**Add:** criteria-level purpose/necessity review, protected-characteristic feature inventory, clinical/legal approval, small-sample-safe outcome monitoring, periodic override/decline review for disparate patterns, and a documented challenge/correction workflow. Do not publish naive subgroup dashboards on tiny cohorts; use governed review with disclosure controls. Success metrics must not reward acceptance rate or fastest confirmation at the expense of safety/equity.

### 3.5 Specify SLA calendars and pause semantics

F3 names paused clocks and S8 names working-hour policies, but neither specifies the hard cases: bank holidays, LA-specific contractual calendars, daylight-saving changes, multiple deadlines, pause authority or a disputed “awaiting information” pause.

**Add:** immutable policy versions with time zone/calendar; acknowledge, clinical-review and response targets; pause/resume events with reason and authoriser; maximum pause/escalation rules; and display of both original contractual deadline and current operational due time. Never overwrite `due_at` without retaining how it was derived.

### 3.6 Design degraded operation and business continuity

Both plans assume auth, Neon, Blob and AI are available. Existing auth fallback pages are technical, not an operational continuity design. A referral desk still needs to know what to do during an AI outage or when a deadline is approaching.

**Add:** service-level objectives and RTO/RPO, dependency-specific status UX, AI-degraded manual triage/evidence mode, durable retry without duplicate ingestion, no unsafe browser/local-storage caching of referral content, and an operations runbook for auth/database/blob outages. “No recommendation” must remain a valid manual workflow, not a dead end.

### 3.7 Make source review accessible for image-only documents

Both plans demand WCAG 2.2 AA for the app shell but do not resolve how a keyboard or screen-reader reviewer examines a scanned PDF/image and its highlighted quote. A canvas-only document pane is not an accessible evidence path.

**Add:** native PDF text layer when present; accessible document/attachment list; keyboard page navigation; structured quote/field transcript alongside the visual source; explicit “machine-extracted, verify against image” status; zoom/reflow; and a supported route for obtaining an accessible source when no reliable text exists. Test the evidence task, not merely the viewer controls.

### 3.8 Complete outcome/handover ownership and feedback boundaries

F3 mentions won/lost/withdrawn and handover in a diagram but does not give them schema, screen, permission or roadmap acceptance criteria; S8 stops close to response tracking. Without this, reporting “win/loss” has no governed source and the capacity commitment can drift from the referral decision.

**Add:** named owner for disposition updates; typed reason codes with optional restricted note; placement/tenancy/package-start link; release of reserved capacity on loss/withdrawal; reconciliation report for decided-but-no-outcome cases; and carefully governed post-start feedback. Operational outcomes may inform offline evaluation, but must not become automatic training labels—commercial wins are not clinical correctness.

### 3.9 Define privacy rules for search, URLs and client persistence

Both plans add search/command navigation without specifying whether names, diagnoses or case numbers appear in URL parameters, browser history, analytics, logs or client caches.

**Add:** server-authorised search; case-insensitive scoped identifiers; no clinical terms/names in URL query strings or telemetry; no raw referral list in local storage; generic document titles; privacy-safe recent-items behaviour; and tests that list/search endpoints cannot reveal cross-scope existence through duplicate warnings or count changes.

## 4. Recommended resolution per major design and architecture decision

| Decision | Converged recommendation | Rejected alternative and rationale |
|---|---|---|
| Product frame | An evidence-first **Referral Operations Workspace** covering intake → triage → source reconciliation → assessment → staffing/commercial → human decision → LA response → disposition/handover. | Recommendation dashboard: reinforces automation bias and omits operational closure. |
| Immediate safety | Patch legacy and v2 so indeterminate/failed evaluations have no decision badge/default; unify review threshold; add an indeterminate outcome store and tests. | Wait for redesign: leaves a known unsafe acceptance path and corrupt recommendation reporting. |
| Rebuild routing | Unique `/workspace/[serviceLine]/**` routes behind a server-side cohort flag; old routes remain; redirect at cutover. | Duplicate `(app)`/`(next)` same paths: build conflict. In-place reskin: poor rollback and mixed semantics. |
| Navigation | Desktop rail + compact mobile task navigation: My work, Referrals, Capacity & matching, Reports; intake CTA; admin by permission. Default landing is role-scoped My work, not a KPI dashboard. | Separate generic `/today` plus `/referrals` if both repeat the same queue; mobile bottom nav that hides the first task below chrome. |
| Referral detail | Stable desktop source/canonical-review/action workspace; task-first mobile routes; URL-addressable sections; current action always clear. | Long card stack; recommendation-first rail; all sections loaded into one client component. |
| Service taxonomy | Explicit Muve `ServiceLine`, orthogonal `Regime` and `PlacementType`; triage-confirmed and scope-aware. | Infer business line solely from regime or extracted placement type. |
| Gate strategy | Freeze seven gates during v2 UI; approve line-scoped evidence/criteria; add explicit applicability only through a later coordinated contract. | Remove gates now or auto-pass compatibility from `soloVsGroup`. |
| Queue priority | Explainable, versioned SLA/urgency/risk bands with visible due time, owner and rank reason; server-side filters/counts/keyset pagination. | Opaque multiplied score or tiny ring/tooltip as the only due signal. |
| Out-of-scope | Dedicated, owned refer-on/exception lane with SLA and no standard accept control. | Demote to bottom or silently discard. |
| Decision control | No preselection; review/correct/confirm as separate stable task; bind extract/evidence/criteria/plan versions; reason for override and material agreement; stale-version diff. | Sidebar dropdown or gesture sheet; confidence-based shortcut for high-confidence accepts. |
| AI confidence | Review reasons and evidence coverage first; numeric confidence secondary; verbal bands only after calibration. | Arbitrary High/Likely/Unsure/Low colours that imply proven correctness. |
| Evidence model | Field-level source anchors, verified/disputed/missing states, human correction overlay and document-set versioning; inert source rendering. | Show source count/confidence only; mutate the raw model extract in place. |
| Capacity | One Capacity & Matching domain with typed adapters: complex-care staffing/setting, supported-living property/tenancy/core support, domiciliary run/time-band/skill headroom. | Generic vacancy sum or universal binary property occupancy. |
| Operational data | Versioned work items, assignments, SLA policies/pauses, decisions, response/disposition and capacity observations/commitments, with current projections. | Single current assignment, `sla_due_at` column and JSONB readiness as the entire history. |
| Backend contracts | Freeze WS-0–WS-5/WS-7 external shapes during Phase 1; add narrow APIs/tables; isolate later service-line/indeterminate contract versions. | Claim the pipeline is “frozen” while changing concurrency in the same work package, or couple UI delivery to a broad contract migration. |
| Component foundation | shadcn source + Radix + Tailwind v4 in a v2 namespace; add TanStack/command/chart libraries only when measured needs justify them. | MUI/Ant override debt; scratch accessibility primitives; install all optional libraries on day one. |
| Typography/colour | Source Sans 3 operational UI, Source Serif 4 reports/editorial only, IBM Plex Mono ids/audit; neutral slate + one provisional Muve primary; semantic risk tokens independent of brand. | Invent “Clearline”, wholesale Inter swap, or use CQC domain colours as status. |
| Theme | Light operational default; user-selected dark stored without flash; both AA. | OS-only theme with no user control or dark palette treated as a colour inversion. |
| Motion | Direct controls, fast press/origin transitions, anchored selection continuity, explicit reduced-motion variants; no motion required to understand state. | Gate staggers, price odometer, ambient pulse or drag-dismiss decision surface. |
| Accessibility | WCAG 2.2 AA minimum plus screen-reader task tests, 400% zoom/reflow, focus-not-obscured, 44px touch baseline, non-colour status and accessible source transcript. | Axe/Lighthouse score as definition of done. |
| Read performance | Narrow typed list/workspace projections, DB counts/ranking, stable indexes, keyset pagination, streamed secondary detail, selected client DTOs. | `SELECT r.*`; long-term JSONB-path extraction on every queue render; full extract passed to client. |
| Progress updates | Cursor/ETag event polling with adaptive backoff and targeted state patch; hidden-tab pause; later consider push only if measured. | Whole RSC `router.refresh()` every 3s or a new real-time vendor before need. |
| Job latency | Neon queue remains; best-effort post-enqueue internal kick plus Cron correctness fallback; configurable bounded concurrency starting at 2, with lease/fairness/rate tests. | Synchronous extraction; replace queue vendor; fixed concurrency 3 without measurement. |
| Intake | Multi-document envelope, type/size/security controls, scoped duplicate compare, amendment flow and idempotency. | Single file; hash-based auto-merge. |
| Notifications | In-app first via idempotent outbox; generic link/stage/due only, no special-category content; email/Teams after channel+DPIA decision. | Web push or referral details in notification payloads. |
| Reporting | Decision/evaluation distinction, criteria/effective-record/plan versions, evidence coverage, overrides, SLA, capacity freshness, response/disposition and redacted audit export. | Count stub accepts, treat document-open as proof of review, or build charts before metric definitions. |
| LA communication | Prepare/copy/download first; typed sent/disposition state; integrate mailbox only after ownership, security and DPIA decision. | Autonomous send or untracked copy/paste. |
| Service-line order | Complex-care v2 first, supported-living vertical slice second, domiciliary third unless the captain supplies a volume/strategy reason to reverse the last two. | Turn on a line from placement-type criteria alone; generic UI fallback. |
| Cutover | Pilot Phase 1 inbox+detail with real users; quantified task/safety gates; cohort ramp; rehearsed rollback; time-boxed legacy deletion. | Permanent dual UI or cutover based only on screenshot parity. |

## 5. Roadmap changes recommended for synthesis

### Phase 0 should start with safety, not tokens

Before design-system implementation:

1. Patch stub/failed outcome presentation and decision preselection in the current UI.
2. Unify the 0.65/0.6 review threshold.
3. Add durable indeterminate evaluation state or, if schema work cannot land immediately, a single server presenter used by queue/detail/report that suppresses the decision whenever status/reason codes show indeterminate; the durable model remains required before reporting.
4. Add the fixture matrix, including screenshot-14 regression.
5. Add request session memoisation and upload envelope limits.
6. Establish the unique `/workspace` route and flag; prove both route trees build and auth correctly.

### Phase 1 should remain the proof slice

Build only the v2 shell, queue read model, role-scoped My work/inbox, authorised evidence delivery, read-only evidence detail and targeted progress updates. Import F3's duplicate cue and “No recommendation” state. Do not yet add decision mutation, property CRUD, command palette, charts or elaborate motion.

Exit criteria should combine both drafts:

- first actionable row visible at 375×812;
- pilot users find the next task and explain its rank reason without help;
- a reviewer finds the exact source for a critical field in under 30 seconds;
- no indeterminate referral displays or reports an advisory decision;
- out-of-scope urgent work remains owned and visible;
- keyboard, screen reader, 400% zoom, both themes and slow-network paths pass;
- list payload contains no raw narrative/source/chat and meets measured latency/size budgets.

### Phase 2 should make human truth durable

Add field verification/correction overlays, source-set amendments, criteria/gate review, staffing/price decomposition, append-only decision storage, neutral review/confirm, LA response preparation and disposition skeleton. Make source/plan/evaluation version invalidation explicit. F3's mobile review sheet should be replaced with the stable task route.

### Phase 3 should add operational truth

Add work-item ownership, versioned SLA calendars/pauses, in-app outbox, typed capacity observations/commitments, supported property readiness where relevant, response-sent/outcome/handover, and bounded job acceleration. Property data requires a named operational owner and expiry before its UI can claim to be live.

### Phase 4 and later

Reporting/admin follows reliable source data, then legacy cutover. Supported living and domiciliary are separate signed vertical slices, not one Phase-4 “placement-scoped criteria” switch. Each needs intake schema, evaluation criteria, commercial model, capacity adapter, terminology, fixtures, clinical/ops/finance sign-off and shadow evaluation before activation.

## Final assessment

F3 should materially change the converged plan: its zero-confidence screenshot exposes a critical defect; its duplicate/multi-file, outcome, commercial decomposition and fixture ideas make the product more operationally complete. Its UI critique is concrete and largely correct.

The converged plan should nevertheless reject F3's route-group mechanism and three domain shortcuts—placement type as service line, universal solo property capacity and automatic solo compatibility pass. Those shortcuts would either fail at build time or bake current assumptions into the wrong layer. The durable recommendation is S8's evidence-first, line-adapted architecture strengthened by F3's safety evidence, with the newly identified indeterminate-outcome, amendment, intake-security, fairness, continuity and accessible-document work added explicitly.
