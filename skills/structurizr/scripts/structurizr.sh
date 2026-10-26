#!/usr/bin/env bash
# Run the Structurizr tooling through Docker. No Java, no MCP.
#
# Usage: structurizr.sh <command> [args...]
#
#   doctor                       check Docker and the image
#   validate [workspace.dsl]     syntax check; exits non-zero on errors
#   inspect  [workspace.dsl]     C4 quality findings; exit code = number of findings
#   export   [workspace.dsl] <format> [outdir]
#                                plantuml | plantuml/c4plantuml | mermaid | json | static | png | svg
#   local    [dir]               serve the browser UI for <dir> (default: .) on $STRUCTURIZR_PORT;
#                                no-op if already serving <dir>, restarts if serving another dir
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
#   STRUCTURIZR_REFRESH_MS       browser polls for DSL changes this often (default 2000; 0 = off)
#   STRUCTURIZR_CONTAINER        container name for `local`/`stop` (default structurizr-local)
#   STRUCTURIZR_FAST=0           skip the unpacked-app cache and run the image as shipped

set -euo pipefail

IMAGE="${STRUCTURIZR_IMAGE:-structurizr/structurizr:latest}"
# Untested: png/svg export needs the browser-bundled image, which has no floating tag.
RENDER_IMAGE="${STRUCTURIZR_RENDER_IMAGE:-structurizr/structurizr:2026.09.19-playwright}"
PORT="${STRUCTURIZR_PORT:-8080}"
MOUNT=/usr/local/structurizr
CONTAINER_NAME="${STRUCTURIZR_CONTAINER:-structurizr-local}"
REFRESH_MS="${STRUCTURIZR_REFRESH_MS:-2000}"

die() { echo "structurizr: $*" >&2; exit 2; }

require_docker() {
  command -v docker >/dev/null 2>&1 || die "docker not found on PATH. Install Docker Desktop (or another Docker engine)."
  docker info >/dev/null 2>&1 || die "Docker daemon is not running. Start Docker Desktop and retry."
}

run() {
  local image="$1"; shift
  if [[ "$image" == "$IMAGE" && "${STRUCTURIZR_FAST:-1}" != 0 ]]; then
    local code
    fast_run "$@" && code=0 || code=$?
    # FAST_RAN is set once the command itself ran, so its exit code is the answer.
    [[ -n "$FAST_RAN" ]] && return "$code"
  fi
  docker run --rm -v "$PWD":"$MOUNT" -w "$MOUNT" "$image" "$@"
}

# The image ships one 211 MB Spring Boot war with 224 nested jars, and every command
# unpacks classes from it at startup: about 30s of CPU per validate. Unpacking it once
# into a volume (per image ID) and keeping a JVM class-data archive there cuts that
# to under 10s. The volume mounts at the image user's home, so it is owned by that user.
FAST_RAN=
fast_run() {
  local id vol err code
  id="$(docker image inspect -f '{{.Id}}' "$IMAGE" 2>/dev/null)" \
    || { docker pull -q "$IMAGE" >/dev/null && id="$(docker image inspect -f '{{.Id}}' "$IMAGE")"; } || return 1
  id="${id#sha256:}"; vol="structurizr-cache-${id:0:12}"
  if ! docker volume inspect "$vol" >/dev/null 2>&1; then
    echo "structurizr: unpacking the image once for faster runs (about a minute)..." >&2
    docker volume create "$vol" >/dev/null || return 1
    if ! docker run --rm -v "$vol":/home/nonroot --entrypoint java "$IMAGE" \
        -Djarmode=tools -jar /usr/local/structurizr.war extract --destination /home/nonroot/app >/dev/null 2>&1; then
      docker volume rm -f "$vol" >/dev/null 2>&1; return 1
    fi
    # Caches for older images are dead weight; one in use by a container is left alone.
    docker volume ls -q --filter name=structurizr-cache- | grep -vx "$vol" | xargs docker volume rm >/dev/null 2>&1 || true
  fi
  err="$(mktemp)"
  FAST_RAN=1
  docker run --rm -v "$PWD":"$MOUNT" -w "$MOUNT" -v "$vol":/home/nonroot --entrypoint java "$IMAGE" \
    -Dio.netty.noUnsafe=true --enable-native-access=ALL-UNNAMED \
    -XX:TieredStopAtLevel=1 -Xlog:cds=off,cds+dynamic=off -XX:+AutoCreateSharedArchive -XX:SharedArchiveFile=/home/nonroot/app.jsa \
    -jar /home/nonroot/app/structurizr.war "$@" 2>"$err" && code=0 || code=$?
  # A half-unpacked cache (an interrupted first run) fails to load classes: drop it
  # and fall back to the shipped image; the next run unpacks again.
  if grep -qE 'Unable to access jarfile|ClassNotFoundException|NoClassDefFoundError|Could not find or load main class' "$err"; then
    rm -f "$err"; FAST_RAN=; docker volume rm -f "$vol" >/dev/null 2>&1; return 1
  fi
  cat "$err" >&2; rm -f "$err"
  return "$code"
}

default_workspace() {
  if [[ -n "${1:-}" ]]; then echo "$1"; return; fi
  [[ -f workspace.dsl ]] || die "no workspace given and ./workspace.dsl not found"
  echo workspace.dsl
}

# Host directory the running `local` container serves, or nothing.
serving_dir() {
  docker inspect -f "{{range .Mounts}}{{if eq .Destination \"$MOUNT\"}}{{.Source}}{{end}}{{end}}" \
    "$CONTAINER_NAME" 2>/dev/null || true
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
    # The server re-reads the DSL on every request, so a running server for
    # the same directory never needs a restart; only a new directory does.
    serving="$(serving_dir)"
    if [[ "$serving" == "$dir" ]]; then
      echo "Already serving $dir at http://localhost:$PORT (edits reload in the browser)"
      exit 0
    elif [[ -n "$serving" ]]; then
      echo "Switching from $serving"
      docker stop "$CONTAINER_NAME" >/dev/null
    fi
    args=(--rm -p "$PORT:8080" -v "$dir":"$MOUNT" --name "$CONTAINER_NAME"
          -e "STRUCTURIZR_AUTOREFRESHINTERVAL=$REFRESH_MS")
    echo "Serving $dir at http://localhost:$PORT"
    if [[ "${STRUCTURIZR_DETACH:-0}" == 1 ]]; then
      docker run -d "${args[@]}" "$IMAGE" local >/dev/null
      # `/` answers before the workspace has loaded, so wait for the workspace
      # API. Not the /workspace/1 page: its first render compiles a JSP, which
      # can take many minutes of CPU on slower Docker hosts.
      printf 'Waiting for server'
      for _ in $(seq 1 100); do
        if [[ "$(curl -s -m 3 -o /dev/null -w '%{http_code}' "http://localhost:$PORT/api/workspace/1")" == 200 ]]; then
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
    sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    die "unknown command '$cmd' (try: help)"
    ;;
esac
