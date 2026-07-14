# Skill snapshot

This directory is the reproducible, non-secret snapshot of every skill source used by the live Firstmate operating home on 2026-07-14.

The audit covered the repository's `.agents/skills`, `.claude/skills`, and `skills`, the generic `~/.agents/skills` root, Pi's `~/.pi/agent/skills` and package resources, Claude's user root and enabled plugin, Codex's user and system roots, and Grok's user, bundled, Claude-compatible, and plugin roots.

[`roots.tsv`](roots.tsv) is the complete observed-root inventory, including empty roots and caches that were deliberately excluded.

## Captured layout

| Path | Owner | Captured skills | License |
| --- | --- | ---: | --- |
| [`.agents/skills`](../.agents/skills) | Firstmate | 12 internal skills | MIT |
| [`skills`](../skills) | Firstmate | 1 installer-facing skill | MIT |
| [`vendor/no-mistakes`](vendor/no-mistakes) | kunchenguid/no-mistakes | 1 skill | MIT |
| [`vendor/emilkowalski-skills`](vendor/emilkowalski-skills) | emilkowalski/skills | 5 skills | MIT |
| [`vendor/rayfernando-skills`](vendor/rayfernando-skills) | RayFernando1337/rayfernando-skills | 2 skills | Apache-2.0 |
| [`vendor/threejs-game-skills`](vendor/threejs-game-skills) | majidmanzarpour/threejs-game-skills | 9 skills | MIT |
| [`vendor/vercel-plugin`](vendor/vercel-plugin) | vercel/vercel-plugin | 28 active plugin skills | Apache-2.0 |

[`sources.tsv`](sources.tsv) is the single owner of source repository, exact revision, license, and captured path provenance.

Every installed community source was matched byte for byte against the revision recorded there before it was copied.

Identical Claude, Codex, and Grok copies are stored once and expanded according to [`restore.tsv`](restore.tsv), so repeated installations do not create repeated vendored source.

The exact snapshot scope is 58 deduplicated top-level skill sources, 78 restore placements, and 458 checksummed files.
[`restore.tsv`](restore.tsv) is authoritative for placements, while [`checksums.sha256`](checksums.sha256) covers the complete captured source set, including repository-local skills, vendor licenses, scripts, references, and assets.

## Harness-managed skills

Codex 0.144.1 contributes five `.system` skills that are coupled to executable helpers and per-skill bundled licenses.

Grok 0.2.99 contributes eight user-stock skills and nine bundled skills, plus shared support files.

The Grok office skills declare proprietary terms but reference missing `LICENSE.txt` files, the other Grok-provided skills have no standalone redistribution grant, and the generated `help` skill contains machine-specific paths.

Those Codex and Grok resources were not copied because reinstalling the exact harness version is the supported way to preserve their helper and runtime coupling, and Grok's terms do not permit treating its files as repository source.

[`harness-managed.tsv`](harness-managed.tsv) records every affected skill name, the exact harness build or plugin revision, the source or install reference, the available license information, and the concrete exclusion reason.

Pi 0.80.6 had no dedicated `~/.pi/agent/skills` directory, and its three installed packages expose themes or extensions rather than skills, so no Pi skill source is missing.
The exact `pi-xai-oauth` and `pi-claude-bridge` provider packages are restored from the project-local [`.pi/settings.json`](../.pi/settings.json) declarations; their extension source is not copied because duplicate registration conflicts, and the theme-only package remains version-recorded in [`harness-managed.tsv`](harness-managed.tsv).

Codex's plugin marketplace tree and Grok's marketplace trees were caches with no installed plugins, so they were inventoried but never copied.

Claude's enabled Vercel plugin is different because its 28 active skills are Apache-2.0 source.

Those skill trees and exact plugin metadata are vendored, while the manifest also preserves the plugin install command for restoring its separate MCP server and hooks.

## Verify and restore

Verify source coverage, provenance structure, checksums, frontmatter names, and relative-link safety from any clone:

```sh
bin/kcode-skills.sh verify
```

Print the deterministic root, source, harness-managed, and placement manifests:

```sh
bin/kcode-skills.sh inventory
```

Restore captured user skills into an explicit home without overwriting different existing installations:

```sh
bin/kcode-skills.sh restore --home /path/to/clean-home
bin/kcode-skills.sh verify-home --home /path/to/clean-home
```

The restore writes normal directories rather than links, and the only repository skill link is the relative `.claude/skills -> ../.agents/skills` link already tracked at the project root.

Pi discovers `no-mistakes` through the restored generic `.agents/skills` root and discovers Firstmate's internal skills directly from this repository.
After project trust, Pi also installs each provider package declared in `.pi/settings.json` exactly once; authentication remains an explicit, separate operator step.

Claude receives `no-mistakes`, the shared community skills, and the captured Vercel skill source.

Codex and Grok receive the same community skill versions they had during the audit, while their version-coupled built-ins remain the responsibility of the pinned harness installations.

No credentials, tokens, caches, generated runtime state, local histories, product repositories, or secret-bearing configuration are part of this snapshot.
