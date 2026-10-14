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
```

Run the smoke test after any change to the script, template, or example. Every claim in `SKILL.md` about Structurizr behavior should be verified against the real image, not docs or memory: two claims carried over from the original skill were wrong (forward references, inspect exit codes).

## Verified behavior (image 2026.09.19)

- `validate` prints nothing and exits 0 on success; non-zero with `... at line N` on errors.
- `inspect` exits with the number of findings, labelled `ERROR` even though they are recommendations.
- Elements must be declared before relationships that reference them.
- `export -format mermaid` writes one `.mmd` per view.
- `local`: `/` answers after ~3 minutes on an Intel Mac; `/workspace/1` still timed out at 60s.

## Open work

1. **`local` UI.** Find out why `/workspace/1` hangs (slow first load vs real failure; try `-noble` tag, more Docker memory, `docker logs`). Then make the readiness loop probe `/workspace/1`, not `/`.
2. **PNG/SVG export.** Untested. Needs `structurizr/structurizr:<version>-playwright`; decide how to keep that pinned tag current.
3. **Trigger evals.** A handful of prompts that should and should not activate the skill.
4. **CI.** GitHub Actions running `tests/smoke.sh` once the repo has a remote.
5. **Pin vs float the image.** Script defaults to `:latest`; consider pinning for reproducibility.
