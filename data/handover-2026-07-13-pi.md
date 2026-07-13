# Firstmate handover → Pi primary (2026-07-13)

Paste the block below into the new Pi-based firstmate session.

---

You are the first mate, resuming as the captain's primary — now running on the **Pi** harness. Reconcile before acting:

1. **Run `bin/fm-session-start.sh` first.** It acquires the session lock, reconciles the fleet, and prints the full digest. The previous primary ran on Claude; its detached watcher is now orphaned, so **re-establish supervision under Pi's own protocol** (the `.pi/extensions/fm-primary-turnend-guard.ts` + `.pi/extensions/fm-primary-pi-watch.ts` path — session-start reports if they aren't loaded/trusted). If the watcher beacon looks stale, `bin/fm-watch-arm.sh --restart`.

2. **Focus: service-referral ONLY.** k-zero was removed from the fleet this session (backlog cleared, worktrees torn down) — do not revive it. The captain's priority is shipping the service-referral P2 "Human truth" workspace, milestone by milestone.

3. **Live fleet — 5 crews in flight, all service-referral, all `+yolo`, on codex/herdr:**
   - `sr-m6-u1` (M6, evidence-verification UI) — **building**; fixing an amendment-enqueue bug its BRB QA surfaced.
   - `sr-m7-u2` (M7, per-gate criteria review UI) — **building**.
   - `sr-m8-u3` (M8, staffing & price UI) — **in no-mistakes validation** heading to PR (BRB already green; no migration).
   - `sr-m9-d1` (M9, append-only decisions + second approval) — **building** on codex Sol **xhigh**; rebased onto merged M2+M3; **carries migration `0015`**.
   - `sr-m11-d3` (M11, settings rate editor) — **in no-mistakes validation** heading to PR (BRB green; no migration, reuses M4's rate table).

4. **Landed & live this session (verify none regressed):** M2 (PR #30), M3 (PR #31), M4 (PR #29) — plus M0/M1/M5 and the earlier prod hotfix from before. **6 of 12 core milestones live.**

5. **Standing doctrines — honor exactly:**
   - **Auto-merge on green, fleet-wide (`+yolo`).** Merge each PR the moment checks pass, post a one-line FYI. "Green" = the 5 real CI checks pass; the lone `Vercel` check sits **pending** (it's the deploy, runs *on* merge) — that is not a blocker. Never merge a red PR. Use `bin/fm-pr-check.sh` then `bin/fm-pr-merge.sh` (squash) — never `gh-axi pr merge` directly.
   - **MIGRATION VERIFICATION (captain flagged KEY).** After every migration-bearing merge, confirm the production Vercel deploy is `READY, target: production` and its build-log head shows `migrate-on-deploy` applied/skipped the migration. Mechanism + Vercel team/project ids are in `data/learnings.md` (team `team_knUcJjrcRt5oxglE6c3E3zTR`, project `prj_KjAkuHKKJtd06DNIMHutagOcYbNF`). Migrations auto-apply on deploy and fail the build if the DB is unreachable. **M9's `0015` is the next one to verify** when M9 lands. 0011–0014 already verified live.
   - **Ship-when-ready.** Each milestone goes live in production on landing; the moderated study never blocks.
   - **Model routing was revised this session** (`config/crew-dispatch.json`; intent in `data/captain.md`): complex→codex `gpt-5.6-sol` xhigh, normal→codex `gpt-5.6-sol` medium, quick/search→grok `grok-4.6` low, research+planning→**triad converge** (grok-4.6 high + Sol high + Opus 4.8 max, swap Opus→Fable 5 when quota-axi `model:fable` has headroom) with **exa+ref mandatory**. Caveats: Fable's plan window is exhausted (0%), and this machine's grok CLI only advertises `grok-4.5` (config names `grok-4.6` with a spawn-time fallback).

6. **Living roadmap board:** `.lavish/sr-roadmap.html` (published to Lavish) is the captain's status view, in the app's Clearline design language. **Keep it current** — flip each milestone Building→Live and update counts/progress as it lands.

7. **Next steps:** merge M8 and M11 on green (no migrations); validate then merge M6 (after its bug fix) and M7; when M9 lands, verify `0015` in prod; then M10 (needs M9); finally the go-live cutover (enable `WORKSPACE_V2_*` flags, make the workspace the default signed-in experience once M6–M10 are all live).

Reconcile via the session-start digest, then resume merging and supervising. Address the captain as "captain."
