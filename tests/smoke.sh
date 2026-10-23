#!/usr/bin/env bash
# Smoke test for the structurizr wrapper. Needs a running Docker daemon.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SZ="$ROOT/skills/structurizr/scripts/structurizr.sh"
fails=0

check() {
  local name="$1" expected="$2"; shift 2
  "$@" >/dev/null 2>&1
  local got=$?
  if [[ "$expected" == 0 && "$got" == 0 ]] || [[ "$expected" != 0 && "$got" != 0 ]]; then
    echo "ok   $name"
  else
    echo "FAIL $name (exit $got)"; fails=$((fails + 1))
  fi
}

cd "$ROOT/skills/structurizr/assets"
check "doctor"                          0 "$SZ" doctor
check "template validates"              0 "$SZ" validate workspace-template.dsl
check "example validates"               0 "$SZ" validate examples/webapp-oauth.dsl
check "inspect exits non-zero on findings" 1 "$SZ" inspect examples/webapp-oauth.dsl
check "absolute outdir rejected"        1 "$SZ" export examples/webapp-oauth.dsl mermaid /tmp/out
check "path outside cwd rejected"       1 "$SZ" validate ../SKILL.md

out=".smoke-mermaid"
check "mermaid export"                  0 "$SZ" export examples/webapp-oauth.dsl mermaid "$out"
n=$(ls "$out"/*.mmd 2>/dev/null | wc -l | tr -d ' ')
[[ "$n" == 3 ]] && echo "ok   mermaid wrote 3 views" || { echo "FAIL mermaid wrote $n views (want 3)"; fails=$((fails + 1)); }
rm -rf "$out"

cd "$ROOT/tests/fixtures/forward-reference"
check "forward reference fails validate" 1 "$SZ" validate

# `local` on its own container and port, so a server you have open is left alone.
export STRUCTURIZR_CONTAINER=structurizr-smoke STRUCTURIZR_PORT=8097 STRUCTURIZR_DETACH=1
url="http://localhost:$STRUCTURIZR_PORT"
tmp="$(mktemp -d)"
mkdir "$tmp/a" "$tmp/b"
cp "$ROOT/skills/structurizr/assets/examples/webapp-oauth.dsl" "$tmp/a/workspace.dsl"
cp "$ROOT/skills/structurizr/assets/workspace-template.dsl" "$tmp/b/workspace.dsl"
trap 'docker stop structurizr-smoke >/dev/null 2>&1; rm -rf "$tmp"' EXIT

check "local starts and serves the workspace" 0 "$SZ" local "$tmp/a"
check "local on the same dir is a no-op"     0 sh -c "\"$SZ\" local \"$tmp/a\" | grep -q 'Already serving'"
perl -0pi -e 's/model \{/model {\n        smokeEdit = person "Smoke Edit"/' "$tmp/a/workspace.dsl"
check "an edit reaches the running server"   0 sh -c "for i in 1 2 3 4 5 6 7 8 9 10; do curl -s $url/api/workspace/1 | grep -q 'Smoke Edit' && exit 0; sleep 1; done; exit 1"
check "browser auto-refresh is on"           0 sh -c "docker inspect -f '{{.Config.Env}}' structurizr-smoke | grep -q 'STRUCTURIZR_AUTOREFRESHINTERVAL=2000'"
check "local on another dir switches"        0 "$SZ" local "$tmp/b"
check "the server now serves the new dir"    0 sh -c "docker inspect -f '{{range .Mounts}}{{.Source}}{{end}}' structurizr-smoke | grep -q '/b\$'"
check "stop"                                 0 "$SZ" stop

echo
[[ $fails == 0 ]] && echo "all passed" || { echo "$fails failed"; exit 1; }
