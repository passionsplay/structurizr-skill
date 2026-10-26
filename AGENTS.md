# structurizr-skill: agent notes

An [Agent Skill](https://agentskills.io/specification) for C4 modeling with the Structurizr DSL, distributed via the [`skills` CLI](https://github.com/vercel-labs/skills) (`npx skills add passionsplay/structurizr-skill`). The skill itself is `skills/structurizr/`; everything else in the repo is for developing it.

## Constraints

- **Docker only.** All Structurizr tooling runs through `skills/structurizr/scripts/structurizr.sh` and the official `structurizr/structurizr` image. Do not add Java, Homebrew, or MCP as requirements. MCP stays an optional reference (`references/mcp.md`).
- **Portable across agents.** No Claude-Code-only features in `SKILL.md` (no `allowed-tools`, no slash commands, no hooks). Scripts are bash, not bun/node.
- **Spec limits.** Frontmatter `name` must equal the folder name (`structurizr`); `description` at most 1024 chars; keep `SKILL.md` well under 500 lines and push detail into `references/` (one level deep).
- **No hard-wrapped prose** in Markdown. One line per paragraph or list item.

## Develop

```bash
tests/smoke.sh                                   # needs Docker running; ~1 min
npx -y skills add . --list                       # confirms the CLI discovers the skill
claude plugin validate .                         # checks .claude-plugin/marketplace.json
evals/run.sh -m <model>                          # skill vs baseline evals; see evals/README.md
```

Run the smoke test after any change to the script, template, or example. Every claim in `SKILL.md` about Structurizr behavior should be verified against the real image, not docs or memory: two claims carried over from the original skill were wrong (forward references, inspect exit codes).

## Verified behavior (image 2026.09.19)

- `validate` prints nothing and exits 0 on success; non-zero with `... at line N` on errors.
- `inspect` exits with the number of findings, labelled `ERROR` even though they are recommendations.
- Elements must be declared before relationships that reference them.
- `export -format mermaid` writes one `.mmd` per view.
- `local`: `/api/workspace/1` returns 200 within about a minute of start. The first `/workspace/1` page render compiles a JSP and scans the WAR; on an Intel Mac (6 Docker CPUs) that has taken from 40s (2026-10-14) to over 15 minutes of pinned CPU (2026-10-23). Later renders are fast, which is the case for leaving the server running.
- `local` re-reads `workspace.dsl` per request: an edit shows in `/api/workspace/1` and bumps `/workspace/lastModified` without a restart.
- `STRUCTURIZR_AUTOREFRESHINTERVAL=<ms>` (env) turns on browser polling of `/workspace/lastModified`; the default is 0 (off).
- Startup cost is the war, not Docker: the image runs one 211 MB Spring Boot war with 224 nested jars, and a no-op container starts in about 1s. The script's fast path unpacks it once per image ID (`java -Djarmode=tools ... extract`) into a `structurizr-cache-<id>` volume mounted at `/home/nonroot` (so the image's user owns it) and runs with a JVM class-data archive and C1-only JIT. Measured 2026-10-26 on an Intel Mac under load: `validate` 20s to 9s, `inspect` 14s to 7s, four concurrent validates 79s to 19s; json and static exports identical. A Docker volume beats a host bind mount (extract 6 min, validate 12s over the bind mount).
- The extracted app has no `WEB-INF/jsp`, so `/workspace/1` 404s from it: `local` keeps running the image as shipped.

## Open work

1. **`local` across projects.** The startup log prints `structurizr.workspaces: 1`; check whether one server can serve several workspaces from a parent folder, which would remove the restart when switching directories.
2. **PNG/SVG export.** Untested. Needs `structurizr/structurizr:<version>-playwright`; decide how to keep that pinned tag current.
3. **Evals.** Task suite v0 lives in `evals/` (pi, containerized by default). First baseline run in `evals/results/`. Still to do: trigger evals (prompts that should and should not activate the skill), a Claude Code adapter (`--bare` needs `ANTHROPIC_API_KEY`).
4. **CI.** GitHub Actions running `tests/smoke.sh`.
5. **Pin vs float the image.** Script defaults to `:latest`; consider pinning for reproducibility.
