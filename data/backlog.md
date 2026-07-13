# Backlog

## In flight
- [ ] kcode-rebuild-g7 - Delete and recreate k-code as the complete Firstmate fork with first-class Grok-imagined README (repo: k-code) (kind: ship) (since 2026-07-14)
- [ ] sr-ci-run-v2 - Run PR 34 checks on a bounded native M5 runner (repo: service-referral) (kind: scout) (since 2026-07-14)
- [ ] sr-m7-u2 - P2 M7: per-gate criteria review UI (merge dark; cohort enable needs study) blocked-by: sr-m3-a4 (repo: service-referral) (kind: ship) (since 2026-07-13)
- [ ] sr-m6-u1 - P2 M6: evidence verification + amendment UI (merge dark; cohort enable needs study) blocked-by: sr-m2-a3 (repo: service-referral) (kind: ship) (since 2026-07-13)
- [ ] sr-m9-d1 - P2 M9: append-only decisions + second approval (0015); enablement needs M5 landed + capability grants (Q3) blocked-by: sr-m4-a5 (repo: service-referral) (kind: ship) (since 2026-07-13)
- [ ] sr-m8-u3 - P2 M8: staffing & price UI (merge dark; small) blocked-by: sr-m4-a5 (repo: service-referral) (kind: ship) (since 2026-07-13)
## Queued
- [ ] sr-m10-d2 - P2 M10: LA response prep + disposition seam (0016) blocked-by: sr-m9-d1 (repo: service-referral) (kind: ship) (since 2026-07-13)
- [ ] sr-golive - SR go-live wiring: as each UI/decision milestone lands green, enable its WORKSPACE_V2_* flags in production immediately (ship-when-ready doctrine); final step makes the workspace the default signed-in experience once M6-M10 are all live blocked-by: sr-m6-u1 blocked-by: sr-m7-u2 blocked-by: sr-m8-u3 blocked-by: sr-m9-d1 blocked-by: sr-m10-d2 (repo: service-referral) (kind: ship) (since 2026-07-13)
- [ ] sr-m11-prod-proof-j5 - Verify M11 production persistence once a real historical priced decision exists (repo: service-referral) (kind: scout) (since 2026-07-13) (hold: wait for first production human_review carrying feeToGoInWeeklyPence) (hold-kind: external)
- [ ] sr-m7-prod-proof-n4 - Verify M7 gate-review persistence with a safe database-backed submission and reload (repo: service-referral) (kind: scout) (since 2026-07-13) (hold: wait for safe non-synthetic production referral review opportunity) (hold-kind: external)
## Done
- [x] pi-ui-max-h7 - Pass Pi --thinking max for Max-reasoning UI dispatch (included in k-code root from upstream PR 537) (repo: firstmate) (kind: ship) (done 2026-07-14)
- [x] sr-ci-fail-v4 - Unblock PR 34 with a safe non-billable native CI path data/sr-ci-fail-v4/report.md (repo: service-referral) (kind: scout) (reported 2026-07-14)
- [x] op-service-account - 1Password prompting friction: crews get auth prompts on every op read, interrupting work (seen mid-generation). Captain to decide: extend auto-lock (quick) OR create a read-only Dev-Env service account and give firstmate the ops_ token to wire into crew env (proper fix, zero prompts) (repo: firstmate) (kind: ship) (done 2026-07-13) (hold: captain to choose fix and provide service-account token if that route) (hold-kind: captain)
  read-only Dev-Env service account vaulted; Keychain-backed crew shell environment verified
- [x] sr-m11-d3 - P2 M11 (captain-optional): settings rate editor https://github.com/korallis/service-referral/pull/33 blocked-by: sr-m4-a5 (repo: service-referral) (kind: ship) (merged 2026-07-13)
- [x] tui-gist-v3 - Draft and publish a reproducible fm-validation TUI guide as a GitHub Gist data/tui-gist-v3/report.md (repo: firstmate) (kind: scout) (reported 2026-07-13)
- [x] sr-m3-a4 - P2 M3: criteria snapshots + grounding sidecar + gate-review domain (0013) https://github.com/korallis/service-referral/pull/31 blocked-by: sr-m1-a2 (repo: service-referral) (kind: ship) (merged 2026-07-13)
- [x] sr-m2-a3 - P2 M2: effective record + append-only field reviews (0012), per-field CAS https://github.com/korallis/service-referral/pull/30 blocked-by: sr-m1-a2 (repo: service-referral) (kind: ship) (merged 2026-07-13)
- [x] sr-m4-a5 - P2 M4: commercial v2 core (fixed-hours arithmetic, versioned rates, fail-closed) + legacy pricing compliance (0014) https://github.com/korallis/service-referral/pull/29 blocked-by: sr-m1-a2 (repo: service-referral) (kind: ship) (merged 2026-07-13)
