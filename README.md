# structurizr-skill

An [Agent Skill](https://agentskills.io/specification) for modeling software architecture as [C4](https://c4model.com/) diagrams with the [Structurizr DSL](https://docs.structurizr.com/dsl). Your coding agent writes `workspace.dsl`, validates it, inspects it for C4 quality, exports it to Mermaid/PlantUML, and serves the interactive browser UI.

Everything runs through the official `structurizr/structurizr` Docker image. No Java install, no MCP server, no per-agent config.

## Install

With the [`skills` CLI](https://github.com/vercel-labs/skills) (works with Claude Code, Cursor, Codex, OpenCode, Copilot, and many more):

```bash
npx skills add passionsplay/structurizr-skill            # current project
npx skills add passionsplay/structurizr-skill -g         # all projects
```

Or by hand: copy (or symlink) `skills/structurizr/` into your agent's skills directory, for example `~/.claude/skills/structurizr` for Claude Code or `.agents/skills/structurizr` in a project.

Requirements: Docker (Docker Desktop or another engine) and bash.

## Use

Ask your agent for an architecture diagram ("model this repo as a C4 container diagram", "validate my workspace.dsl", "export the views to Mermaid"). The skill triggers on its description.

The wrapper script also works on its own:

```bash
cd path/to/model
skills/structurizr/scripts/structurizr.sh doctor
skills/structurizr/scripts/structurizr.sh validate workspace.dsl
skills/structurizr/scripts/structurizr.sh inspect workspace.dsl
skills/structurizr/scripts/structurizr.sh export workspace.dsl mermaid diagrams
skills/structurizr/scripts/structurizr.sh local            # http://localhost:8080
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
```

## Status

| Feature | State |
|---|---|
| validate / inspect / Mermaid export | Tested against `structurizr/structurizr` 2026.09.19 |
| `local` browser UI | Partial: `/` answers after ~3 min on an Intel Mac, but `/workspace/1` still timed out at 60s. Needs investigation |
| PNG/SVG export | Untested; needs the `-playwright` image variant |

## License

MIT
