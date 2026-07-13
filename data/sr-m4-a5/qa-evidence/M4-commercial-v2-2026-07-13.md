# M4 — Commercial v2 core + legacy pricing-window compliance

**Date:** 2026-07-13  
**Branch:** `fm/sr-m4-a5`  
**Scope:** Flat charge-out defect fix, migration 0014 rate cards, legacy surface §4b compliance

## Acceptance checklist

| Criterion | Result |
| --- | --- |
| Σ hours exact for 1:1/2:1/3:1 × nursing mix (incl. Q2 override) | PASS — `flat-pricing.test.ts` (20 tests) |
| Old 504 h over-count expectation gone (2:1+nursing = 336 h) | PASS — explicit regression test |
| Rate edit → new version; never mutates stored card rates | PASS — `rate-cards.test.ts` publish path + migration immutability |
| Fail closed when DB configured-but-unavailable | PASS — `resolveChargeOutRates` db_error / no_active_card |
| Dev constants labelled, not bindable | PASS — `bindable: false`, ratesSource marker |
| Forbidden-key recursive scan (on-cost/absence/property/margin/offered-fee/override) | PASS — `findForbiddenCommercialKey` + queue DTO extensions |
| Pipeline stops `applyDeterministicCommercialOverlay` for new snapshots | PASS — pipeline no longer imports/calls overlay; unit suite green |
| Legacy WorkingPlanPanel read-only + forbidden metrics hidden + superseded note | PASS — component test |
| Legacy review-chat UI flag-disabled (`LEGACY_REVIEW_CHAT_UI_ENABLED = false`) | PASS — single gate in referral detail page |
| Baseline fee card hides margin/staffing-cost/offered-fee | PASS — page change + evidence report superseded |
| No `CONTRACT_VERSION` / `DECISION_GATES` / `regimeSchema` / queue-rank-v1 changes | PASS (git diff empty on those) |
| Migration 0014 shape + seed `seed:sr-plan-4b` v1 {hca:3200,rmn:6500} | PASS — migration SQL + shape test |
| Migrations applied twice on disposable Neon | **DEFERRED** — no `DATABASE_URL_UNPOOLED` in worktree; shape tests green; apply in CI/deploy |
| e2e workspace-p1 sentinel (Flat charge-out, no on-cost lines) | Run at no-mistakes / e2e gate |
| screenshot-14 suite | PASS within full unit suite (727 tests) |

## Engine verification evidence

```
npx vitest run src/lib/workspace/__tests__/flat-pricing.test.ts \
  src/lib/commercial/__tests__/rate-cards.test.ts \
  src/lib/db/__tests__/rate-cards-migration.test.ts \
  src/components/referrals/__tests__/working-plan-panel.test.tsx
# → all green
```

Key arithmetic proofs:

- 2:1 + nursing default → 168 HCA + 168 RMN = **336 h** (not 504)
- 3:1 + nursing default → 336 HCA + 168 RMN = **504 h**
- 1:1 + nursing default → 0 HCA + 168 RMN = **168 h**
- Q2 override 2:1 + rmnHours=84 → 252 HCA + 84 RMN = **336 h**

## Legacy UI BRB scope (real-user)

Target flows on running app (375×812 + 1280×800, light + dark):

1. Legacy `/referrals/[id]` with working plan: panel read-only; no Edit inputs; superseded note visible; no Staff cost / Property / Margin / Offered fee metrics.
2. No review-chat rail or mobile chat sheet when recommendation present.
3. Baseline fee card: funding risk only; superseded copy; no fee/cost/margin metrics.
4. Workspace staffing tab (when enabled): Flat charge-out copy; Σ hours line; no on-cost list items.

**Auth gate:** disposable worktree has no Neon Auth / session credentials; interactive browser pass deferred to preview/deploy with `SR_SMOKE_*` or pilot login. Component + page unit coverage exercises the DOM contracts above.

## Disjoint domains (parallel M2/M3)

Did **not** touch field-review (`0012`) or criteria/gates (`0013`) files.

## Neon migration evidence (0014) — 2026-07-13 re-run

Environment: disposable Neon via worktree `.env.local` (`DATABASE_URL_UNPOOLED`).

| Check | Result |
| --- | --- |
| First `npm run db:migrate` | `apply 0014_charge_out_rate_cards.sql` |
| Second `npm run db:migrate` | `skip 0014_charge_out_rate_cards.sql (already applied)` |
| Seed v1 | `{hca:3200,rmn:6500}`, `created_by=seed:sr-plan-4b`, status=active |
| Rates UPDATE | REJECTED — `rates/identity are immutable after insert` |
| DELETE | REJECTED — `append-only: DELETE is not permitted` |
| Second active INSERT | REJECTED — `idx_charge_out_rate_cards_one_active` |

## Legacy UI BRB evidence — 2026-07-13

Dev server: `localhost:3456` with `WORKSPACE_V2_PILOT_SESSION=1` (non-prod pilot reviewer).
Referral: `697169cd-3aed-472b-9a67-f58f0a07a715` (needs_review + working plan).

Screenshots under `docs/qa/runs/assets-m4/`:
- `legacy-detail-mobile-light.png` (375×812)
- `legacy-detail-desktop-light.png` (1280×800)
- `legacy-detail-mobile-dark.png` / `legacy-detail-desktop-dark.png` (emulated)

Observed:
- Working plan: **Superseded pricing model**, read-only, no Edit inputs / Save
- No Staff cost / Property / Gross contribution / Offered fee metric cards
- No review-chat rail or composer
- Baseline fee card: funding risk only + superseded copy
- Pre-F1 fix still showed historical draft fee £ amount (to be removed by captain decision)

