# structurizr-skill

An [Agent Skill](https://agentskills.io/specification) for modeling software architecture as [C4](https://c4model.com/) diagrams with the [Structurizr DSL](https://docs.structurizr.com/dsl). Your coding agent writes `workspace.dsl`, validates it, inspects it for C4 quality, exports it to Mermaid/PlantUML, and serves the interactive browser UI.

Everything runs through the official `structurizr/structurizr` Docker image. No Java install, no MCP server, no per-agent config.

## Install

With the [`skills` CLI](https://github.com/vercel-labs/skills) (works with Claude Code, Cursor, Codex, OpenCode, Copilot, and many more):

```bash
npx skills add passionsplay/structurizr-skill            # current project
npx skills add passionsplay/structurizr-skill -g         # all projects
```

As a Claude Code plugin:

```bash
claude plugin marketplace add passionsplay/structurizr-skill
claude plugin install structurizr@passionsplay
```

Or by hand: copy (or symlink) `skills/structurizr/` into your agent's skills directory, for example `~/.claude/skills/structurizr` for Claude Code or `.agents/skills/structurizr` in a project.

Requirements: Docker (Docker Desktop or another engine) and bash.

### First run and disk use

The first command pulls `structurizr/structurizr` (about 280 MB) and then unpacks it once into a Docker volume named `structurizr-cache-<image id>` (about 210 MB), which takes one to two minutes. After that, `validate` and `inspect` take under 10 seconds instead of the 20 to 30 seconds the image needs as shipped, because every launch of the shipped image unpacks classes from a 211 MB Spring Boot archive. When the image updates, the next run builds a new cache and removes the old one. To opt out, set `STRUCTURIZR_FAST=0`; to reclaim the space, `docker volume rm` the cache volume.

## Use

Ask your agent for an architecture diagram ("model this repo as a C4 container diagram", "validate my workspace.dsl", "export the views to Mermaid"). The skill triggers on its description.

The wrapper script also works on its own:

```bash
cd path/to/model
skills/structurizr/scripts/structurizr.sh doctor
skills/structurizr/scripts/structurizr.sh validate workspace.dsl
skills/structurizr/scripts/structurizr.sh inspect workspace.dsl
skills/structurizr/scripts/structurizr.sh export workspace.dsl mermaid diagrams
skills/structurizr/scripts/structurizr.sh local            # http://localhost:8080; leave it running, edits reload
```

## Layout

```
skills/structurizr/
├── SKILL.md                      # instructions the agent loads
├── scripts/structurizr.sh        # Docker wrapper: doctor, validate, inspect, export, local, stop
├── references/                   # loaded on demand
│   ├── dsl-best-practices.md
│   ├── validate-vs-inspect.md
│   └── mcp.md                    # optional MCP server setup
└── assets/
    ├── workspace-template.dsl
    └── examples/webapp-oauth.dsl
tests/smoke.sh                    # end-to-end checks against the real image
evals/                            # skill vs no-skill evals; see evals/README.md
```

## Status

| Feature | State |
|---|---|
| validate / inspect / Mermaid, JSON, static export | Tested against `structurizr/structurizr` 2026.09.19, through the cache and as shipped (identical output) |
| `local` browser UI | Tested; runs the image as shipped (the cache lacks the web pages). API ready in about a minute; the first page render can take minutes on slow Docker hosts (JSP compile); DSL edits reload in the browser without a restart |
| PNG/SVG export | Untested; needs the `-playwright` image variant |

## License

MIT
