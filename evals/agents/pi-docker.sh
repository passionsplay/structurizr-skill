#!/usr/bin/env bash
# Agent adapter: run pi headless inside the trial container (evals/docker/Dockerfile).
#
# Usage: pi-docker.sh <model> <skill|baseline> <prompt-file>
#
# The work dir is mounted at the same absolute path as on the host, and the host Docker socket
# is mounted, so structurizr.sh inside the container starts the Structurizr image on the host
# daemon and its $PWD mount still resolves. The agent sees the work dir, the skill (skill
# condition only), and nothing else from the host filesystem. It can still reach the host
# Docker daemon: this isolates the filesystem, it is not a sandbox against a hostile agent.
#
# Environment:
#   OPENROUTER_API_KEY   passed into the container; defaults to pi's stored OpenRouter credential
#   PI_VERSION           pi version to build into the image (default 1.1.0)

set -euo pipefail

model="$1" cond="$2" prompt="$3"
version="${PI_VERSION:-1.1.0}"
image="sz-eval-pi:$version"
here="$(cd "$(dirname "$0")" && pwd)"

docker image inspect "$image" >/dev/null 2>&1 \
  || docker build -q --build-arg "PI_VERSION=$version" -t "$image" "$here/../docker" >&2

# Inherited by name (-e VAR) so the key never appears in a process listing.
export OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-$(pi auth print-bearer-token --provider openrouter 2>/dev/null || true)}"

# A killed `docker run` client leaves its container running, so name it and remove it on exit
# (the runner's timeout sends TERM).
name="sz-eval-$$-$RANDOM"
trap 'docker rm -f "$name" >/dev/null 2>&1 || true' EXIT
trap 'exit 124' TERM INT

mounts=(-v "$PWD:$PWD" -w "$PWD" -v /var/run/docker.sock:/var/run/docker.sock)
args=(-p --no-session --mode json --model "$model"
      --no-context-files --no-approve --no-extensions --no-mcp --no-prompt-templates --no-skills)

case "$cond" in
  skill)    mounts+=(-v "$SKILL_DIR:/skills/structurizr:ro"); args+=(--skill /skills/structurizr) ;;
  baseline) ;;
  *) echo "pi-docker.sh: unknown condition: $cond" >&2; exit 2 ;;
esac

docker run --rm --name "$name" "${mounts[@]}" -e OPENROUTER_API_KEY "$image" "${args[@]}" "$(cat "$prompt")" </dev/null &
wait $!
