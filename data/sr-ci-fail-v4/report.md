# PR 34 native CI scout report

Date: 2026-07-14  
Repository: `korallis/service-referral`  
PR: https://github.com/korallis/service-referral/pull/34  
PR head: `5bb5740109eda3aed50b79e2c39200f3be931509`

## Outcome

**A workflow change is required before a self-hosted M5 runner can safely receive these jobs.** I therefore did not change or push the shared branch, did not register a runner, and did not rerun or alter any check. PR 34 remains red and must not be approved or merged.

The smallest safe, coverage-preserving change is four `runs-on` replacements that route only PR 34 to the unique repo-runner label `sr-ci-m5`, while retaining the existing hosted labels for every other PR and `main` push. Job names, commands, environment, and all four check contexts stay unchanged.

## What GitHub currently shows

All GitHub reads were made with `gh-axi`.

- `gh-axi repo view korallis/service-referral`: repository is **private**.
- `gh-axi api /repos/korallis/service-referral/collaborators/korallis/permission`: current credential has repository `admin`, sufficient to manage a repository-scoped runner.
- `gh-axi api /repos/korallis/service-referral/actions/runners`: `total_count: 0`; no repository runner was present.
- `gh-axi api /repos/korallis/service-referral/actions/permissions`: Actions enabled; allowed actions `all`.
- `gh-axi api /repos/korallis/service-referral/actions/permissions/workflow`: default workflow token permission is `read`; it cannot approve PR reviews.
- `gh-axi api /repos/korallis/service-referral/branches/main/protection`: GitHub returned `404 Branch not protected`. I made no protection/settings change and do not treat this as permission to bypass checks.
- PR 34 is open, same-repository/owner-authored (not a fork), mergeable but `unstable`, with four red Actions checks.

The current-head workflow run is `29290324211`, run number 21. Attempts 1, 2, and 3 all produced the same result. For example:

```text
GET /repos/korallis/service-referral/actions/runs/29290324211/attempts/{1,2,3}/jobs
four jobs per attempt
status: completed
conclusion: failure
steps: []
runner_id: 0
runner_name: ""
labels: ubuntu-latest (three jobs), macos-latest (visual job)
wall time: roughly 1–4 seconds
```

Each check annotation says:

```text
The job was not started because recent account payments have failed or your
spending limit needs to be increased.
```

`gh-axi run view 29290324211 --log-failed` returns `log not found`, consistent with no runner ever starting. The four genuine contexts that must be made green are:

1. `Typecheck, lint, unit tests`
2. `Bundle budget (inbox / evidence)`
3. `Playwright e2e (default + workspace)`
4. `Playwright visual baselines (P1 surfaces)`

For historical clarity, run `29289688465` was on older SHA `0e3f11d...`: unit, bundle, and functional E2E genuinely passed on hosted runners, while all six visual tests failed. That older run is not a green result for the current head. The later current-head attempts did not execute any step.

## Exact routing blocker

At PR-head `.github/workflows/ci.yml`:

- line 15: `unit` uses `ubuntu-latest`
- line 29: `bundle-budget` uses `ubuntu-latest`
- line 55: `e2e` uses `ubuntu-latest`
- line 89: `e2e-visual` uses `macos-latest`

Those are GitHub-hosted image labels. A supported self-hosted route uses a repository runner's default labels (`self-hosted`, `macOS`, `ARM64`) and/or a unique custom label. Existing workflow-run labels cannot be edited during a rerun.

I rejected assigning the hosted names `ubuntu-latest`/`macos-latest` as custom labels to the M5. That would falsely describe macOS as Ubuntu and, more importantly, collision with GitHub-hosted labels is not a supported/reliable way to force self-hosted routing. It cannot guarantee a non-billable runner receives the job. The official route is an explicit unique self-hosted label.

The workflow has only `push` on `main` and `pull_request`; there is no dispatch/input seam that can select a runner without changing the workflow.

## Minimal required diff

The PR owner should apply this through their normal validation pipeline; this scout must not push it.

```diff
diff --git a/.github/workflows/ci.yml b/.github/workflows/ci.yml
--- a/.github/workflows/ci.yml
+++ b/.github/workflows/ci.yml
@@ -12,7 +12,7 @@ jobs:
   unit:
     name: Typecheck, lint, unit tests
-    runs-on: ubuntu-latest
+    runs-on: ${{ github.event_name == 'pull_request' && github.event.pull_request.number == 34 && 'sr-ci-m5' || 'ubuntu-latest' }}
@@ -26,7 +26,7 @@ jobs:
   bundle-budget:
     name: Bundle budget (inbox / evidence)
-    runs-on: ubuntu-latest
+    runs-on: ${{ github.event_name == 'pull_request' && github.event.pull_request.number == 34 && 'sr-ci-m5' || 'ubuntu-latest' }}
@@ -52,7 +52,7 @@ jobs:
   e2e:
     name: Playwright e2e (default + workspace)
-    runs-on: ubuntu-latest
+    runs-on: ${{ github.event_name == 'pull_request' && github.event.pull_request.number == 34 && 'sr-ci-m5' || 'ubuntu-latest' }}
@@ -86,7 +86,7 @@ jobs:
   e2e-visual:
     name: Playwright visual baselines (P1 surfaces)
@@
-    runs-on: macos-latest
+    runs-on: ${{ github.event_name == 'pull_request' && github.event.pull_request.number == 34 && 'sr-ci-m5' || 'macos-latest' }}
```

Why this form rather than four unconditional self-hosted arrays:

- It is bounded to PR 34; concurrent PRs and `main` retain their current routing.
- It avoids leaving `main` dependent on a temporary runner after cleanup.
- `sr-ci-m5` is unique and can only match the explicitly registered repository runner.
- A scalar custom label is valid `runs-on` syntax. The runner still receives its normal `self-hosted`, `macOS`, and `ARM64` labels at registration.
- All four jobs keep exactly the same steps and check names. One runner will execute them sequentially; this changes capacity, not coverage.

Do not replace jobs, remove commands, mark contexts successful externally, or weaken the workflow.

## Native-runner feasibility

Host probe: `Darwin 25.5.0 arm64` (native Apple Silicon M5).

Official runner evidence:

- `gh-axi api /repos/actions/runner/releases/latest` reports official runner `v2.335.1`.
- It includes `actions-runner-osx-arm64-2.335.1.tar.gz`, SHA-256 `e1a9bc7a3661e06fa0b129d15c2064fe65dc81a431001d8958a9db1409b73769`.
- GitHub's official self-hosted-runner reference supports macOS 11+ and macOS ARM64. Repository-scoped self-hosted runner execution does not consume billable hosted-runner minutes; machine and any Actions storage remain the owner's responsibility.
- Official routing docs: https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/use-in-a-workflow
- Official requirements/reference: https://docs.github.com/en/actions/reference/runners/self-hosted-runners
- Official billing: https://docs.github.com/en/billing/concepts/product-billing/github-actions

The only potentially Linux-flavoured command is `npx playwright install --with-deps chromium`. A local dry run completed successfully and selected `mac-arm64` Chromium/headless-shell downloads, so the existing command can remain unchanged. `actions/setup-node@v4` is configured for Node 22 and supports macOS ARM64. The visual job already requires macOS-matched baselines.

## Bounded execution contract after the diff is accepted

1. Before the PR-owner push, create one named non-default Herdr lab exactly through `fm-herdr-lab.sh`, with the mandated EXIT teardown trap.
2. Inside a Herdr pane whose cwd and runner files are under this disposable worktree, download and SHA-verify the official `osx-arm64` package above.
3. Register exactly one **repository-scoped** runner with custom label `sr-ci-m5`; keep normal `self-hosted`, `macOS`, `ARM64` labels. Do not create an org/enterprise runner or change runner groups/branch protection.
4. Fetch registration/removal tokens only with `gh-axi`, pass them directly through in-memory command substitution to `config.sh`, never echo them, write them to a file, include them in Herdr pane commands/scrollback, or place them in shell history. Start the runner with a sanitized job `HOME`/`TMPDIR` inside the worktree and no unrelated host secrets in its environment.
5. Confirm through `gh-axi api /repos/korallis/service-referral/actions/runners` that the named runner is online with `sr-ci-m5`; then let the PR owner push the validated four-line change.
6. Observe the new `pull_request` run. Verify every job reports the bounded runner's nonzero `runner_id`/`runner_name`, has real steps/logs, and all four named contexts reach a genuine terminal conclusion. One runner means the four jobs queue and run serially.
7. If any test fails, retain the red result and inspect the genuine log; never approve or merge it.
8. Immediately after the run reaches a genuine terminal result (or if coordination stops), stop the listener, unregister it with an in-memory removal token obtained via `gh-axi`, verify the repo runner list is empty, delete its worktree-local files, and teardown only through the lab helper. Never leave a runner available after the bounded window.

## Herdr/safety state from this scout

I provisioned short-lived named labs only to verify the helper/CLI and cleanup contract; no GitHub runner or token was created. Every provision was preceded by the required EXIT trap and every Herdr command went through `fm-herdr-lab.sh`. A final isolated inventory showed exactly one running `default` session, the current non-default lab, and `stale_sr_ci_fail_v4: []`; successful trap teardown then removed the current lab. No direct/global Herdr lifecycle command was used.

No repository file, remote branch, PR, GitHub setting, check context, or runner registration was changed.

## Recommendation

Have the existing PR owner apply the four-line conditional `runs-on` diff above through the normal no-mistakes pipeline. Coordinate the push only after the bounded `sr-ci-m5` repo runner is online in the isolated Herdr lab. Accept no merge recommendation until the new current-SHA run contains real logs and all four native contexts are green.
