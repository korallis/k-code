# Captain preferences

## Dispatch and model routing (REVISED 2026-07-13)

Captain's revised routing (supersedes the earlier claude-complex / grok-main scheme):

- **UI implementation and polish** -> pi, `openai-codex/gpt-5.6-sol`, effort **max** (Pi 0.80.6 `--thinking max`, smoke-tested; UI research/planning still uses the triad).
- **Complex non-UI work** -> pi, `openai-codex/gpt-5.6-sol`, effort **xhigh** (Extra High; explicit provider avoids Pi resolving the short model name to unauthenticated Azure).
- **Normal / main non-UI implementation work** -> pi, `openai-codex/gpt-5.6-sol`, effort **medium**.
- **Quick tasks or folder/code searches** -> pi, `xai-auth/grok-4.5`, effort **low**.
- **Research AND planning work** -> **TRIAD CONVERGE**: spawn ALL THREE - pi `xai-auth/grok-4.5` (high), pi `openai-codex/gpt-5.6-sol` (high), and claude Opus 4.8 (`claude-opus-4-8`, max) - as coordinating co-draft scouts; each drafts, cross-reviews the others, firstmate converges into one synthesis. THIRD-VOICE QUOTA SWAP: use Fable 5 (`claude-fable-5`, max) in place of Opus 4.8 whenever Fable is within plan limits (check `quota-axi` claude `model:fable` window: percentRemaining > 0 -> Fable, else Opus). Every research/planning scout MUST use the **exa** and **ref** MCP servers for sources.
- no-mistakes gate validation agent -> pi, `openai-codex/gpt-5.6-sol`, medium (configured in `~/.no-mistakes/config.yaml`; explicit provider required because Pi otherwise resolved the short model name to unauthenticated Azure).
- Firstmate and secondmates -> claude on Fable 5 (`claude-fable-5`), effort max; fall back to Opus 4.8 max only if Fable 5 becomes unavailable.
- Concrete per-task rules live in `config/crew-dispatch.json`; this section records the intent behind them.
- **Model-availability caveats (2026-07-13)**: Pi's xAI provider currently exposes `xai-auth/grok-4.5` but not Grok 4.6, so Grok-voice work uses that explicit, smoke-tested route until 4.6 appears. Fable 5's plan window was **exhausted (0% remaining)** when this was set, so the triad third voice resolves to Opus 4.8 until Fable's window recovers.

## Current priority (set 2026-07-13)

- **service-referral is the highest-priority project** ("This needs to be built today"). New dispatch capacity goes to SR first; k-zero continues in parallel but yields contention to SR.
- **SR SHIP-WHEN-READY doctrine (captain, 2026-07-13)**: the new UI "should just appear as soon as it's ready" - each milestone goes LIVE in production (flags on) the moment it is built, wired, and green through no-mistakes + BRB. The moderated study never blocks enablement (may run later as feedback). Ship as fast as possible WITH every guard fully in force. Parallel development is key: fan milestones out concurrently wherever files are disjoint; serialize only true dependencies.

## Execution style (set 2026-07-13)

- **No-mistakes delivery for every project (captain, 2026-07-14)**: every current and future project uses the `no-mistakes` ship path; do not use `direct-PR` or `local-only` unless the captain explicitly grants a one-task exception. The destructive `k-code` repository rebuild requested on 2026-07-14 is the sole current exception; once recreated, `k-code` returns to `no-mistakes +yolo` for all future work.
- **Auto-merge on green, fleet-wide for repos the captain controls**: every captain-owned project runs `+yolo` (k-zero, service-referral, and k-code all set; reaffirmed by captain 2026-07-13 "auto merge all pr's when green" and 2026-07-14 "Always merge when green"). This does **not** include contribution PRs to the upstream `kunchenguid/firstmate` repository; those wait for the upstream owner, while the captain-controlled Firstmate fork carrying all our adjustments is `k-code`. A repo with no CI configured counts as green. Firstmate merges any controlled-repo PR the moment its checks pass, posts a one-line FYI, and only stops for destructive/irreversible/security-sensitive actions or a red PR. Review-gate findings are resolved on firstmate judgment.
- **Parallelize aggressively but safely**: open every independent lane that owns disjoint files; keep same-file/same-subsystem work serial; later-lander rebases + regenerates shared artifacts. Split phases by file ownership when possible (e.g. k-zero AI vs track content vs weapons).
- **Real-user QA always, every project**: running-bug-review-board pass on the running app before done, driven like a user, layered on top of no-mistakes. Binding rules and quality bars live in `data/learnings.md` (AAA/fun bar, pilot-the-ship, generation-first assets, universal BRB).

## Plan delivery: always Lavish (set 2026-07-13)

Every substantial plan relayed to the captain gets a lavish-axi review page - decision tables, roadmap, diagrams - not just chat/markdown. Load the relevant lavish playbooks (plan/comparison/diagram) before building the page. Chat carries only the short digest plus a pointer to the review page.

**Preferred page layout (captain, 2026-07-13)**: fixed left sidebar (brand block + anchor nav + footnote), main column of eyebrow-labeled sections (small uppercase kicker, big headline, one-line description), numbered finding cards (01/02/03...), inline product mockups rendered in the proposed design system, screenshot figures with verdict captions, an "Opinionated decisions" table with columns Decision / Recommendation / REJECTED alternative, and phase cards for the roadmap. Modeled on the S8 draft page the captain singled out.

## Research & planning: triad co-draft (REVISED 2026-07-13)

Whenever a feature is planned OR a deep-research task is run, spawn THREE coordinating scouts, not two:

1. pi `xai-auth/grok-4.5` at effort high.
2. pi `openai-codex/gpt-5.6-sol` at effort high.
3. claude Opus 4.8 (`claude-opus-4-8`) at effort max - OR Fable 5 (`claude-fable-5`, max) instead when Fable is within plan limits (quota-axi `model:fable` percentRemaining > 0).

Each drafts, then each cross-reviews the others' drafts (relay drafts between them; they share no window). Firstmate synthesizes the converged final plan/report and relays it to the captain. Every one of these scouts MUST use the exa and ref MCP servers for sources. This applies to research and feature planning; ordinary scout investigations (bug repro, audits) follow the normal dispatch rules.
