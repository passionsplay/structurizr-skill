# Grading helpers for eval cases. A case's check.sh sources this and runs in the agent's work dir.
#
# Output contract, one line each:
#   PASS <gate> / FAIL <gate>   pass/fail checks; a trial passes only if every gate passes
#   METRIC <name> <value>       numbers tracked over time, never pass/fail
#
# Expects SZ (wrapper script) and TRANSCRIPT (agent output) in the environment.

WS="${WS:-workspace.dsl}"
JSON=".grade/${WS%.dsl}.json"

# All explicit relationships; implied ones carry linkedRelationshipId and are skipped.
REL='[.. | objects | select(has("sourceId") and has("destinationId") and (has("linkedRelationshipId") | not))]'

gate() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "PASS $name"; else echo "FAIL $name"; fi
}

metric() { echo "METRIC $1 $2"; }

q() { jq -r "$1" "$JSON" 2>/dev/null; }

has_workspace() { [[ -f "$WS" ]]; }
validates()     { "$SZ" validate "$WS"; }
at_least()      { (( ${1:-0} >= $2 )); }

# Export the workspace to JSON once so the queries below can read the parsed model.
export_json() {
  rm -rf .grade
  "$SZ" export "$WS" json .grade >/dev/null 2>&1
}

view_count()    { q "(.views.$1 // []) | length"; }
rel_count()     { q "$REL | length"; }
component_count() { q '[.model.softwareSystems[]?.containers[]?.components[]?] | length'; }

# Case-insensitive ERE match against any element name.
has_element() {
  q '[.. | objects | select(has("name") and has("tags") and (has("sourceId") | not)) | .name] | .[]' | grep -Eiq "$1"
}

# Percent of explicit relationships that name a technology.
tech_coverage() {
  q "$REL | if length == 0 then 0 else (map(select((.technology // \"\") != \"\")) | length) * 100 / length | floor end"
}

# Relationships into a component from outside its container (another container, or a
# component of another container): the "which components do callers use" rule.
cross_container_component_rels() {
  q '
    ([.model.softwareSystems[]?.containers[]? as $c | $c.components[]? | {key: .id, value: $c.id}] | from_entries) as $parent
    | ([.model.softwareSystems[]?.containers[]?.id]) as $containers
    | [ '"$REL"'[]
        | .sourceId as $s | .destinationId as $d
        | select($parent[$d] != null)
        | select((($containers | index($s)) != null and $s != $parent[$d])
                 or ($parent[$s] != null and $parent[$s] != $parent[$d])) ]
    | length'
}

# inspect exits with its finding count; capped at 255 by the shell.
inspect_findings() { "$SZ" inspect "$WS" >/dev/null 2>&1; echo $?; }

# Tool calls whose shell command contains a pattern (pi transcript format).
tool_calls_matching() {
  jq -rs --arg re "$1" '[.[] | select(.type == "message_end") | .message | select(.role == "assistant")
    | .content[]? | select(.type == "toolCall") | (.arguments.command // "") | select(test($re))] | length' \
    "$TRANSCRIPT" 2>/dev/null || echo 0
}

# Metrics every case reports, after its own gates.
common_metrics() {
  # Quality metrics only mean something for a workspace that parses.
  if [[ -f "$WS" ]] && validates >/dev/null 2>&1; then
    [[ -f "$JSON" ]] || export_json
    metric inspect_findings "$(inspect_findings)"
    metric tech_coverage_pct "$(tech_coverage)"
  fi
  metric validate_calls "$(tool_calls_matching 'validate')"
}
