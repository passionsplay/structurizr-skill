#!/usr/bin/env bash
# Agent adapter: run pi headless in the current directory and stream its JSON events to stdout.
#
# Usage: pi.sh <model> <skill|baseline> <prompt-file>
#
# Context files, extensions, MCP, and prompt templates are off in both conditions so the
# only difference between them is whether the structurizr skill is loaded.
#
# Environment:
#   PI_EXTENSIONS   space-separated extension paths to load anyway, e.g. a model provider
#                   such as ~/.pi/agent/npm/node_modules/pi-opencode-free/dist/index.js

set -euo pipefail

model="$1" cond="$2" prompt="$3"

args=(-p --no-session --mode json --model "$model"
      --no-context-files --no-approve --no-extensions --no-mcp --no-prompt-templates --no-skills)

for ext in ${PI_EXTENSIONS:-}; do args+=(-e "$ext"); done

case "$cond" in
  skill)    args+=(--skill "$SKILL_DIR") ;;
  baseline) ;;
  *) echo "pi.sh: unknown condition: $cond" >&2; exit 2 ;;
esac

exec pi "${args[@]}" "$(cat "$prompt")" </dev/null
