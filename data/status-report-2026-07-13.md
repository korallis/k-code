# Bearings - Monday 2026-07-13

Six changes are live: two Firstmate reliability fixes and four service-referral milestones are validating or applying approved findings. The service-referral foundation through M5, plus the M11 settings editor, has landed; no k-zero Unity-pivot work is currently live or queued.

## Captain's Call

Nothing needs your action right now. Both Firstmate review fixes are approved and underway, and the durable 1Password service-account solution is configured.

No PR is merge-ready at this snapshot.

## Recently Landed

### service-referral

- https://github.com/korallis/service-referral/pull/25 - production `evaluation_runs` migration repair, fail-closed deploy migrations, and graceful degradation.
- https://github.com/korallis/service-referral/pull/26 - M0 fixture repair, parse guard, visual baselines, and CI bundle budgets.
- https://github.com/korallis/service-referral/pull/27 - M1 evidence/source/extract version foundation, amendment API, and opaque delivery.
- https://github.com/korallis/service-referral/pull/28 - M5 TDDI architecture, live-Ofsted removal, corpus v2, and child-TDDI safety bridges.
- https://github.com/korallis/service-referral/pull/29 - M4 fixed-hours commercial core, versioned rates, fail-closed pricing, and legacy compliance.
- https://github.com/korallis/service-referral/pull/30 - M2 effective records, append-only field reviews, and per-field CAS.
- https://github.com/korallis/service-referral/pull/31 - M3 criteria snapshots, grounding sidecar, and gate-review domain.
- https://github.com/korallis/service-referral/pull/33 - M11 settings rate editor.

### Firstmate operations

- https://github.com/kunchenguid/firstmate/pull/527 - updated Grok effort guidance for the current `high` ceiling.
- `data/tui-gist-v3/report.md` - reproducible validation-dashboard TUI guide published.
- A read-only Dev-Env service account is vaulted and exposed to new crew shells through a Keychain-backed environment; authenticated read access is verified without repeated 1Password prompts.

## Underway

- **pi-ui-max-h7 / Firstmate** - implementation and focused checks pass; the approved Pi-Max profile-validator fix is being applied through validation.
- **pi-watch-active-k9 / Firstmate** - reload-safe activation and restart handling are implemented; the approved restart-handoff ownership fix is being applied through validation.
- **sr-m6-u1 / service-referral** - M6 evidence verification and amendment UI; the current fixes are authorized to preserve human overlays on Verify and expose terminal extraction failures with an intentional retry path.
- **sr-m7-u2 / service-referral** - M7 per-gate criteria review UI is actively validating.
- **sr-m8-u3 / service-referral** - M8 staffing and price UI is actively validating on https://github.com/korallis/service-referral/pull/32; it is recorded but not yet merge-ready.
- **sr-m9-d1 / service-referral** - M9 append-only decisions and second approval resumed after a transient validation-agent failure and is actively applying its rebase/fix round.

## Charted Next

- **sr-m10-d2** - LA response preparation and disposition seam, blocked on M9.
- **sr-golive** - enable each completed workspace milestone in production as it lands; final default-experience cutover waits on M6-M10.
- **sr-m11-prod-proof-j5** - waits for the first real historical priced decision carrying the required fee snapshot.
- **sr-m7-prod-proof-n4** - waits for a safe, non-synthetic production referral review to verify persistence and reload.
