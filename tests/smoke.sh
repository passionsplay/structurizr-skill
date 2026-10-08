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

echo
[[ $fails == 0 ]] && echo "all passed" || { echo "$fails failed"; exit 1; }
