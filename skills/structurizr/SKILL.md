---
name: structurizr
description: Create, validate, inspect, export, and preview C4 architecture models written in Structurizr DSL, using only Docker (no Java, no MCP server). Use when the user wants an architecture diagram, a C4 model (system context, container, component views), a workspace.dsl file, or to check, render, or export an existing Structurizr workspace to Mermaid, PlantUML, PNG, or SVG.
license: MIT
compatibility: Requires Docker (Docker Desktop or another engine) and bash. Network access on first run to pull structurizr/structurizr.
metadata:
  author: passionsplay
  version: "0.1.0"
---

# Structurizr

Model software architecture as code with the [Structurizr DSL](https://docs.structurizr.com/dsl) and the [C4 model](https://c4model.com/). All tooling runs through `scripts/structurizr.sh`, a thin wrapper over the official `structurizr/structurizr` Docker image.

Run the script by its path inside this skill directory, from the directory that holds the workspace (it mounts the current directory into the container):

```bash
<skill-dir>/scripts/structurizr.sh doctor                     # Docker + image check
<skill-dir>/scripts/structurizr.sh validate [workspace.dsl]   # syntax; non-zero exit on error
<skill-dir>/scripts/structurizr.sh inspect  [workspace.dsl]   # C4 quality recommendations
<skill-dir>/scripts/structurizr.sh export   [workspace.dsl] mermaid [outdir]
<skill-dir>/scripts/structurizr.sh local    [dir]             # browser UI on :8080
```

## Workflow: create or change a model

1. **Find or start the workspace.** Look for an existing `workspace.dsl` first. For a new one, copy `assets/workspace-template.dsl` and adapt it. `assets/examples/webapp-oauth.dsl` shows a fuller model with component-level detail.
2. **Ask before guessing boundaries.** If it is unclear what is inside the system versus external, or which C4 level the user wants, ask. Default to System Context + Container views; add Component views only for containers the user cares about.
3. **Write the DSL** following the rules below. For deeper guidance read `references/dsl-best-practices.md`.
4. **Validate** with `structurizr.sh validate`. Fix every error and re-run until it exits 0. Do not report a model as done until validate passes.
5. **Inspect** with `structurizr.sh inspect` when the user asks about quality or completeness. Summarize findings; do not treat them as failures. See `references/validate-vs-inspect.md`.
6. **Show it.** Offer `export ... mermaid` for something that renders inline in Markdown/GitHub, or `local` for the interactive browser UI.

## DSL rules that prevent most failures

- **Prefer flat identifiers.** Skip `!identifiers hierarchical` unless two elements would otherwise share an identifier. Flat identifiers must be unique across the whole model.
- **Define elements before relationships that use them.** The DSL is parsed top to bottom, so a forward reference fails with `The destination element "x" does not exist`, the same error as a typo. Declare all elements first, then relationships (cross-container ones go after both containers' blocks).
- **Show which components other containers call.** Keep `spa -> api` for the container view and add `spa -> authController` for the component view, so the component diagram answers "what breaks if I change this?"
- **Give every relationship a description and a technology:** `a -> b "Reads orders from" "HTTPS/JSON"`. Use `"In-process call"` between components in one container. Missing technology is the most common inspect finding.
- **Be specific with technology:** "Express Router", "TypeORM", "PostgreSQL 16", not "JavaScript".
- **Component granularity:** controllers, services, repositories, external clients. Not individual functions; not "Business Logic Layer".
- **Tag external systems** (`"External"`) and style the tag so internal and external read differently.
- **Set `configuration { scope softwaresystem }`** (or `landscape`) to clear the scope recommendation.

## Gotchas

- **Validate and inspect are different tools.** `validate` answers "will this parse?" and exits non-zero on errors. `inspect` answers "is this a good C4 model?", prints its findings with an `ERROR` label, and still exits 0. A workspace can validate cleanly and have dozens of inspect findings.
- **Paths must be inside the current directory.** The container only sees the mounted directory. `cd` to the workspace's directory before running the script; output directories must be relative.
- **`local` is slow to start.** On some Docker hosts the server takes several minutes before it answers HTTP. With `STRUCTURIZR_DETACH=1` the script waits for it; in the foreground, wait for the page rather than assuming it failed. Open `http://localhost:8080/`, which redirects to `/workspace/1`.
- **`local` writes a `.structurizr/` folder** next to the workspace (logs, search index, layout). Suggest adding it to `.gitignore`. Manual layout tweaks made in the UI are saved to `workspace.json`; keep that file if the user wants layouts preserved.
- **PNG/SVG export needs a different image** (`structurizr/structurizr:<version>-playwright`, which bundles a browser). There is no floating `playwright` tag; override with `STRUCTURIZR_RENDER_IMAGE`. Prefer Mermaid or PlantUML export when an image file is not strictly needed.
- **Structurizr Lite and the old `structurizr/cli` image are deprecated.** Their commands now live in the single `structurizr/structurizr` image (`local`, `validate`, `inspect`, `export`, ...). Translate old instructions accordingly.

## Optional: MCP server

An MCP server exists (`structurizr/mcp`) but is not needed for this skill. If the user specifically wants it, read `references/mcp.md`.
