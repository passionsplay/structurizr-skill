# Changelog

Notable changes to the `structurizr` skill. Versions follow [semver](https://semver.org/); the version also lives in `skills/structurizr/SKILL.md` frontmatter.

## 0.2.0 (2026-10-26)

### Added

- Claude Code plugin marketplace manifest: `claude plugin marketplace add passionsplay/structurizr-skill`, then `claude plugin install structurizr@passionsplay`.
- `local` is start-once: re-running it for the directory it already serves is a no-op, running it for another directory replaces the server, and the browser reloads on DSL edits (`STRUCTURIZR_REFRESH_MS`, default 2000; 0 turns it off). `STRUCTURIZR_CONTAINER` names the container.
- Eval suite in `evals/`: five task cases run with and without the skill, graded by Structurizr itself, in an isolated container, with cost and token capture and parallel trials (`-j`). Results in `evals/results/`; on DeepSeek V4 Flash at k=3 the skill passes 15/15 against 7/15 to 9/15 without it.

### Changed

- `validate`, `inspect`, and `export` are about twice as fast, and about four times as fast when several run at once. The first command after a new image unpacks it once into a Docker volume, `structurizr-cache-<image id>` (about 210 MB, one to two minutes); later commands skip most of the class unpacking the shipped image repeats on every launch. Older cache volumes are removed automatically. `STRUCTURIZR_FAST=0` opts out. Outputs and exit codes are unchanged; `local` still runs the image as shipped.
- `SKILL.md` warns against `theme default` and other themes on `static.structurizr.com`: the Structurizr cloud service reached end of life on 30 September 2026 and `validate` now fails on them.
- Docs no longer promise that `inspect` exits with the finding count. From image 2026.10.26 it exits 1 when there are findings.

### Fixed

- `local` with `STRUCTURIZR_DETACH=1` waits for the workspace API instead of the first page render, which could take over 15 minutes of CPU on slow Docker hosts and made the wait time out.

## 0.1.0 (2026-10-14)

First public release: `SKILL.md`, the Docker wrapper (`doctor`, `validate`, `inspect`, `export`, `local`, `stop`, `raw`), references, template, example, and smoke test. Install with `npx skills add passionsplay/structurizr-skill`.
