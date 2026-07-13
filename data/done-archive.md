
## Archived 2026-07-13
- [x] plan-fable-r7 - AAA cyberpunk F-Zero overhaul plan - co-draft A (cross-review pending) data/plan-fable-r7/report.md (repo: k-zero) (kind: scout) (reported 2026-07-13)

## Archived 2026-07-13
- [x] plan-sol-w2 - AAA cyberpunk F-Zero overhaul plan - co-draft B (cross-review pending) data/plan-sol-w2/report.md (repo: k-zero) (kind: scout) (reported 2026-07-13)

## Archived 2026-07-13
- [x] fix-track-b4 - fix track visibility, inverted steering, turn-rate smoothing https://github.com/korallis/k-zero/pull/1 (repo: k-zero) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] n0-contain - N0 network containment gate: respawn token validation, checkpoint wiring + 2-client test, Solo/Online boot adapters, rematch contract, disconnect/DNF policy (plan section 5) https://github.com/korallis/k-zero/pull/2 blocked-by: fix-track-b4 (repo: k-zero) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] p1-runtime - P1: 60Hz fixed-tick GameRuntime + input ring + test hooks scaffold https://github.com/korallis/k-zero/pull/3 blocked-by: n0-contain (repo: k-zero) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] p1-feel - P1: quick feel wins - camera package, speed lines, display multiplier, coast rule https://github.com/korallis/k-zero/pull/4 blocked-by: p1-runtime (repo: k-zero) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] p1-compiler - P1: RMF track compiler + hashed gameplay artifact + validate CLI + golden fixtures https://github.com/korallis/k-zero/pull/5 blocked-by: p1-feel (repo: k-zero) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] p1-controller - P1: CraftController v2 - freq/damping suspension, airbrakes, sideshift, drift https://github.com/korallis/k-zero/pull/6 blocked-by: p1-compiler (repo: k-zero) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] p1-slice - P1: time-trial vertical slice - readability, onboarding, minimal audio, line bot; blind-tester gate https://github.com/korallis/k-zero/pull/7 blocked-by: p1-controller (repo: k-zero) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] p2-combat - P2: offline combat phase (split into PR tasks when current) - respawn, inventory+absorb, pickups, roster, balance bots blocked-by: p1-slice (repo: k-zero) (kind: ship) (done 2026-07-13)
  split into p2-energy..p2-balance

## Archived 2026-07-13
- [x] p2-energy - P2.1: shared energy economy 0-1000 - boost drain, fatal boost, recharge strips, HUD energy bar https://github.com/korallis/k-zero/pull/8 (repo: k-zero) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] asset-overhaul - AAA asset rebuild via Tripo3D - hero ship set, environment kit, pickup/strip visuals, provenance manifest, budget-verified https://github.com/korallis/k-zero/pull/9 (repo: k-zero) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] p2-respawn - P2.2: destruction + literal-pose 1s respawn, ghost/grace, fall recovery https://github.com/korallis/k-zero/pull/10 blocked-by: p2-energy (repo: k-zero) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] sr-plan-f3 - service-referral ground-up UI rebuild + optimization plan - co-draft A data/sr-plan-f3/report.md (repo: service-referral) (kind: scout) (reported 2026-07-13)

## Archived 2026-07-13
- [x] sr-plan-s8 - service-referral ground-up UI rebuild + optimization plan - co-draft B data/sr-plan-s8/report.md (repo: service-referral) (kind: scout) (reported 2026-07-13)

## Archived 2026-07-13
- [x] p2-items - P2.3: two-slot inventory + absorb + pickup rows/sockets/roll system https://github.com/korallis/k-zero/pull/11 blocked-by: p2-respawn (repo: k-zero) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] sr-stub-hotfix - SAFETY HOTFIX: failed/zero-confidence evaluations render green Accept preselected - suppress badge/default, remove all decision preselection, unify 0.65/0.6 threshold, regression tests https://github.com/korallis/service-referral/pull/21 (repo: service-referral) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] fix-fallthrough - CRITICAL: craft falls through track at speed - reproduce, root-cause, fix + soak regression https://github.com/korallis/k-zero/pull/12 (repo: k-zero) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] p3-track2 - P3a (parallelized): Black Rain Foundry greybox + compiled track content - buildable independent of AI; bot-gate stays in P3 exit https://github.com/korallis/k-zero/pull/13 blocked-by: p2-items (repo: k-zero) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] p5-audio - P5a (parallelized): audio asset pack - ElevenLabs SFX generation + license-free music hunt + provenance manifest; content-only, no sim code https://github.com/korallis/k-zero/pull/14 (repo: k-zero) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] asset-tripo-web - AAA hero asset pass via Tripo STUDIO web (browser automation, uses the paid 25,500 Studio credits) - 3 hero ships + key props, download GLBs, optimize, integrate https://github.com/korallis/k-zero/pull/15 (repo: k-zero) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] p2-weapons-core - P2.4: weapons core - Pulse/Arc/Mine + telegraph/counter framework + control-loss caps https://github.com/korallis/k-zero/pull/16 blocked-by: p2-items (repo: k-zero) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] p3-ai-core - P3b (parallelized): racing AI core - line following, personalities, overtake planner, competition director; NO item use (needs only landed runtime/controller/artifact) https://github.com/korallis/k-zero/pull/17 blocked-by: p2-items (repo: k-zero) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] sr-clearline - Rebuild parallel lane: Clearline design-token foundation - the token package (colors/type/spacing OKLCH, light+dark, semantic risk/confidence tokens) + tailwind v4 config + a token showcase page; standalone, consumed by P1 shell, touches nothing P0/backend https://github.com/korallis/service-referral/pull/23 (repo: service-referral) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] sr-p0 - Rebuild P0: safety+enablers - indeterminate evaluation state, fixture matrix, /workspace route+flag, Neon auth-dep escalation (plan sr-plan.md) https://github.com/korallis/service-referral/pull/22 blocked-by: sr-stub-hotfix (repo: service-referral) (kind: ship) (merged 2026-07-13)
  CAPTAIN GO given 2026-07-13 ("The referral rebuild, let's go") - dispatch this automatically the moment sr-stub-hotfix lands; no further captain gate on dispatch. Scope: plan data/sr-plan.md P0 - durable indeterminate evaluation state, fixture matrix incl screenshot-14 regression, session memoization + upload limits, /workspace/[serviceLine] route + server cohort flag (build+auth proof), Neon auth-dependency escalation note. PRs still need captain merge word (yolo off).

## Archived 2026-07-13
- [x] p2-weapons-full - P2.5: Seeker/Rail/EMP-Quake + Aegis/countermeasures/Overdrive/Nanite utilities https://github.com/korallis/k-zero/pull/18 blocked-by: p2-weapons-core (repo: k-zero) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] kz-environment - AAA environment + track-surface pass: Tripo-generated set dressing, floor/surface detail, visible boost-pad/speed-strip floor treatment, hazards/bumps, pickup-pad glow - builds on landed hero assets https://github.com/korallis/k-zero/pull/19 blocked-by: asset-tripo-web (repo: k-zero) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] kcode-readme-g4 - k-code README glow-up: grok /imagine hero banner + art under docs/assets, README rewrite w/ mermaid diagram + badges, direct-PR https://github.com/korallis/k-code/pull/6 (repo: k-code) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] kz-vfx - AAA VFX + juice pass: boost exhaust VFX, weapon projectile trails+muzzle+impact, shield bubble/hit, countermeasure/EMP FX, destruction burst, respawn shimmer, ALL HUD bar/timer animations, hitstop/shake - every effect fires and reads at speed, piloted-QA verified https://github.com/korallis/k-zero/pull/20 blocked-by: p2-weapons-full (repo: k-zero) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] kz-ships-8 - 8 selectable ships: generate 5 MORE Tripo hero craft (total 8, distinct silhouettes/liveries), expand ship-select so player picks 1 of 8 after hitting Play, on EVERY track/mode. LODs + budgets + provenance; piloted+BRB QA that each ship is flyable https://github.com/korallis/k-zero/pull/21 blocked-by: kz-environment (repo: k-zero) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] sr-p1 - Rebuild P1: proof slice - Clearline tokens, shell, explainable queue, My work, read-only evidence detail; exit = moderated task study https://github.com/korallis/service-referral/pull/24 blocked-by: sr-p0 (repo: service-referral) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] kz-p5-art-t2 - P5 production-art content lane pulled forward: Tripo props + set dressing + menu/UI art, content-only, Tier-A budgets, BRB piloted QA https://github.com/korallis/k-zero/pull/22 (repo: k-zero) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-13
- [x] sr-p2-plan-c7 - SR P2 planning co-draft A (Fable 5 max): P2 plan from sr-plan.md on P0+Clearline+P1; cross-review with sr-p2-plan-x4 data/sr-p2-plan-c7/report.md (repo: service-referral) (kind: scout) (reported 2026-07-13)

## Archived 2026-07-13
- [x] sr-p2-plan-x4 - SR P2 planning co-draft B (gpt-5.6-sol xhigh): same scope; cross-review with sr-p2-plan-c7 data/sr-p2-plan-x4/report.md (repo: service-referral) (kind: scout) (reported 2026-07-13)

## Archived 2026-07-13
- [x] sr-migrate-h3 - URGENT prod fix: evaluation_runs migration missing in prod Neon - /queue + /referrals 500ing; apply migration, prevent recurrence, graceful degradation https://github.com/korallis/service-referral/pull/25 (repo: service-referral) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-14
- [x] sr-m0-a1 - P2 M0: fixture repair + parse guard + visual baselines + CI bundle budgets https://github.com/korallis/service-referral/pull/26 (repo: service-referral) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-14
- [x] fix-grok-effort-doc - harness-adapters skill: grok 0.2.99 dropped xhigh (ceiling now high, rejects max+xhigh); update the launch-profile table + captain.md reference. Ship via firstmate no-mistakes pipeline https://github.com/kunchenguid/firstmate/pull/527 (repo: firstmate) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-14
- [x] sr-m1-a2 - P2 M1: evidence/source/extract version foundation (0011) + amendment API + opaque delivery https://github.com/korallis/service-referral/pull/27 blocked-by: sr-m0-a1 (repo: service-referral) (kind: ship) (merged 2026-07-13)

## Archived 2026-07-14
- [x] sr-m5-b1 - P2 M5 Lane B: TDDI ADR + live-Ofsted removal + corpus v2 + child_tddi safety bridges https://github.com/korallis/service-referral/pull/28 (repo: service-referral) (kind: ship) (merged 2026-07-13)
