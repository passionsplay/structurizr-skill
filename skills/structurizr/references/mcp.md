# Optional: Structurizr MCP server

This skill does not need MCP: the Docker CLI covers validate, inspect, and export. Use the MCP server only if the user specifically wants Structurizr tools exposed to the agent as MCP tools (`validate`, `parse`, `inspect`, Mermaid/PlantUML export).

## Run the server

```bash
docker run -d --rm --name structurizr-mcp -p 3000:3000 -e PORT=3000 \
  structurizr/mcp -dsl -plantuml -mermaid
```

The server speaks MCP over HTTP at `http://localhost:3000/mcp`. A public instance with the same tools runs at `https://mcp.structurizr.com/mcp` (sends the DSL to a third party; ask first).

## Connect an agent

Claude Code supports HTTP MCP servers directly; no bridge is needed:

```bash
claude mcp add --transport http structurizr http://localhost:3000/mcp            # this project only
claude mcp add --transport http --scope user structurizr http://localhost:3000/mcp  # all projects
```

Check with `claude mcp list` or `/mcp` in a session. Clients that only support stdio (older Claude Desktop builds, some editors) need the `mcp-remote` bridge: `npx mcp-remote http://localhost:3000/mcp --allow-http`.

## Source

https://docs.structurizr.com/ai/mcp
