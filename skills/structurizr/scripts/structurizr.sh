#!/usr/bin/env bash
# Run the Structurizr tooling through Docker. No Java, no MCP.
#
# Usage: structurizr.sh <command> [args...]
#
#   doctor                       check Docker and the image
#   validate [workspace.dsl]     syntax check; exits non-zero on errors
#   inspect  [workspace.dsl]     C4 quality recommendations (always exits 0)
#   export   [workspace.dsl] <format> [outdir]
#                                plantuml | plantuml/c4plantuml | mermaid | json | static | png | svg
#   local    [dir]               serve the browser UI for <dir> (default: .) on $STRUCTURIZR_PORT
#   stop                         stop a background `local` server
#   raw      <args...>           pass arguments straight to the structurizr binary
#
# The current directory (or the dir given to `local`) is mounted into the
# container, so workspace paths must live inside it.
#
# Environment:
#   STRUCTURIZR_IMAGE            default structurizr/structurizr:latest
#   STRUCTURIZR_RENDER_IMAGE     image for png/svg export (needs the -playwright variant)
#   STRUCTURIZR_PORT             default 8080
#   STRUCTURIZR_DETACH=1         run `local` in the background

set -euo pipefail

IMAGE="${STRUCTURIZR_IMAGE:-structurizr/structurizr:latest}"
# Untested: png/svg export needs the browser-bundled image, which has no floating tag.
RENDER_IMAGE="${STRUCTURIZR_RENDER_IMAGE:-structurizr/structurizr:2026.09.19-playwright}"
PORT="${STRUCTURIZR_PORT:-8080}"
MOUNT=/usr/local/structurizr
CONTAINER_NAME=structurizr-local

die() { echo "structurizr: $*" >&2; exit 2; }

require_docker() {
  command -v docker >/dev/null 2>&1 || die "docker not found on PATH. Install Docker Desktop (or another Docker engine)."
  docker info >/dev/null 2>&1 || die "Docker daemon is not running. Start Docker Desktop and retry."
}

run() {
  local image="$1"; shift
  docker run --rm -v "$PWD":"$MOUNT" -w "$MOUNT" "$image" "$@"
}

default_workspace() {
  if [[ -n "${1:-}" ]]; then echo "$1"; return; fi
  [[ -f workspace.dsl ]] || die "no workspace given and ./workspace.dsl not found"
  echo workspace.dsl
}

check_inside_pwd() {
  local abs
  abs="$(cd "$(dirname "$1")" 2>/dev/null && pwd)" || die "directory for $1 does not exist"
  [[ "$abs" == "$PWD" || "$abs" == "$PWD"/* ]] || die "$1 is outside the current directory; cd to its directory first"
}

cmd="${1:-help}"; shift || true

case "$cmd" in
  doctor)
    require_docker
    echo "ok   docker daemon running"
    if docker image inspect "$IMAGE" >/dev/null 2>&1; then
      echo "ok   image $IMAGE present"
    else
      echo "info image $IMAGE not pulled yet (first run will pull it)"
    fi
    run "$IMAGE" version 2>&1 | sed -n "s/.*-- structurizr: /ok   structurizr /p"
    ;;
  validate|inspect)
    require_docker
    ws="$(default_workspace "${1:-}")"
    check_inside_pwd "$ws"
    run "$IMAGE" "$cmd" -workspace "$ws"
    ;;
  export)
    require_docker
    if [[ $# -ge 2 ]]; then ws="$1"; fmt="$2"; out="${3:-diagrams}"
    else ws="$(default_workspace "")"; fmt="${1:-}"; out="diagrams"; fi
    [[ -n "$fmt" ]] || die "usage: export [workspace.dsl] <format> [outdir]"
    check_inside_pwd "$ws"
    [[ "$out" != /* ]] || die "outdir must be relative to the current directory"
    image="$IMAGE"
    [[ "$fmt" == png || "$fmt" == svg ]] && image="$RENDER_IMAGE"
    run "$image" export -workspace "$ws" -format "$fmt" -output "$out"
    ;;
  local)
    require_docker
    dir="$(cd "${1:-.}" && pwd)"
    [[ -f "$dir/workspace.dsl" || -f "$dir/workspace.json" ]] || die "$dir has no workspace.dsl or workspace.json"
    args=(--rm -p "$PORT:8080" -v "$dir":"$MOUNT" --name "$CONTAINER_NAME")
    echo "Serving $dir at http://localhost:$PORT"
    if [[ "${STRUCTURIZR_DETACH:-0}" == 1 ]]; then
      docker run -d "${args[@]}" "$IMAGE" local >/dev/null
      # Startup can take minutes on slower Docker hosts; wait until HTTP answers.
      printf 'Waiting for server'
      for _ in $(seq 1 100); do
        if curl -s -o /dev/null "http://localhost:$PORT/"; then
          echo " ready."
          echo "Running in background. Stop with: $0 stop"
          exit 0
        fi
        printf '.'; sleep 3
      done
      echo
      die "server did not answer within 5 minutes; check: docker logs $CONTAINER_NAME"
    else
      [[ -t 0 ]] && args=(-it "${args[@]}")
      exec docker run "${args[@]}" "$IMAGE" local
    fi
    ;;
  stop)
    require_docker
    docker stop "$CONTAINER_NAME" >/dev/null && echo "stopped $CONTAINER_NAME"
    ;;
  raw)
    require_docker
    run "$IMAGE" "$@"
    ;;
  help|-h|--help)
    sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    die "unknown command '$cmd' (try: help)"
    ;;
esac
