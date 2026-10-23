#!/usr/bin/env bash
# Run eval cases against an agent: cases x models x conditions x trials, graded by each case's check.sh.
#
# Usage: evals/run.sh [-m model]... [-c case]... [-k trials] [-C skill,baseline] [-a agent] [-t seconds]
#
#   -m  model id for the agent (repeatable; default $EVAL_MODEL)
#   -c  case directory name under evals/cases (repeatable; default all)
#   -k  trials per cell (default 1; use 3+ for pass^k)
#   -C  comma-separated conditions (default skill,baseline)
#   -a  agent adapter under evals/agents (default pi-docker; pi runs on the host)
#   -t  per-trial timeout in seconds (default 600)
#
# Each trial runs in a fresh temp dir outside the repo, and by default inside a container that
# sees only that dir, so the baseline cannot find the skill or host tools by wandering.
# Artifacts and grades land in evals/runs/<run-id>/ (gitignored).

set -uo pipefail

EVALS="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$EVALS")"
export SZ="$ROOT/skills/structurizr/scripts/structurizr.sh"
export SKILL_DIR="$ROOT/skills/structurizr"
export EVAL_LIB="$EVALS/lib/grade.sh"

models=() cases=() conds=(skill baseline)
k=1 agent=pi-docker timeout_s=600

usage() { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

while getopts "m:c:k:C:a:t:h" opt; do
  case "$opt" in
    m) models+=("$OPTARG") ;;
    c) cases+=("$OPTARG") ;;
    k) k="$OPTARG" ;;
    C) IFS=, read -ra conds <<<"$OPTARG" ;;
    a) agent="$OPTARG" ;;
    t) timeout_s="$OPTARG" ;;
    *) usage ;;
  esac
done

(( ${#models[@]} )) || { [[ -n "${EVAL_MODEL:-}" ]] && models=("$EVAL_MODEL"); }
(( ${#models[@]} )) || { echo "no model: pass -m or set EVAL_MODEL" >&2; exit 2; }
(( ${#cases[@]} )) || while IFS= read -r c; do cases+=("$c"); done < <(ls "$EVALS/cases")
[[ -x "$EVALS/agents/$agent.sh" ]] || { echo "no adapter: evals/agents/$agent.sh" >&2; exit 2; }
"$SZ" doctor >/dev/null || { echo "structurizr doctor failed; is Docker running?" >&2; exit 2; }

run_id="$(date +%Y%m%d-%H%M%S)"
out="$EVALS/runs/$run_id"
results="$out/results.tsv"
mkdir -p "$out"
printf 'case\tagent\tmodel\tcond\ttrial\tpass\tgates\tseconds\texit\tmetrics\n' > "$results"

# Headless runs cannot answer questions, so every prompt gets the same unattended note.
unattended=$'\n\nYou are running unattended: nobody can answer questions. Make reasonable assumptions, state them briefly, and finish the task.'

for case in "${cases[@]}"; do
  cdir="$EVALS/cases/$case"
  [[ -f "$cdir/prompt.md" && -f "$cdir/check.sh" ]] || { echo "skip $case: needs prompt.md and check.sh" >&2; continue; }
  for model in "${models[@]}"; do
    for cond in "${conds[@]}"; do
      for trial in $(seq 1 "$k"); do
        dest="$out/$case/$agent--${model//\//_}/$cond/$trial"
        mkdir -p "$dest"
        { cat "$cdir/prompt.md"; printf '%s\n' "$unattended"; } > "$dest/prompt.md"

        work="$(mktemp -d "${TMPDIR:-/tmp}/sz-eval.XXXXXX")"
        [[ -d "$cdir/setup" ]] && cp -R "$cdir/setup/." "$work/"

        start=$(date +%s)
        (cd "$work" && timeout "$timeout_s" "$EVALS/agents/$agent.sh" "$model" "$cond" "$dest/prompt.md") \
          > "$dest/transcript.jsonl" 2> "$dest/agent.stderr"
        code=$?
        secs=$(( $(date +%s) - start ))

        (cd "$work" && TRANSCRIPT="$dest/transcript.jsonl" bash "$cdir/check.sh") > "$dest/grade.txt" 2>&1

        passed=$(grep -c '^PASS' "$dest/grade.txt" || true)
        total=$(grep -cE '^(PASS|FAIL)' "$dest/grade.txt" || true)
        pass=0; (( total > 0 && passed == total )) && pass=1
        metrics=$(awk '/^METRIC/ { printf "%s%s=%s", sep, $2, $3; sep = ";" }' "$dest/grade.txt")
        # Agent-reported spend, priced from the agent's model catalog.
        usage=$(jq -rs '[.[] | select(.type == "message_end") | .message | select(.role == "assistant") | .usage]
                        | "cost_usd=\(map(.cost.total // 0) | add // 0);tokens=\(map(.totalTokens // 0) | add // 0)"' \
                  "$dest/transcript.jsonl" 2>/dev/null || echo "cost_usd=0;tokens=0")
        metrics="${metrics:+$metrics;}$usage"

        mkdir -p "$dest/work"
        (cd "$work" && tar --exclude .structurizr -cf - .) | (cd "$dest/work" && tar -xf -)
        rm -rf "$work"

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s/%s\t%s\t%s\t%s\n' \
          "$case" "$agent" "$model" "$cond" "$trial" "$pass" "$passed" "$total" "$secs" "$code" "$metrics" >> "$results"
        printf '%-4s %-28s %-40s %-8s #%s  %s/%s gates  %ss\n' \
          "$([[ $pass == 1 ]] && echo ok || echo FAIL)" "$case" "$model" "$cond" "$trial" "$passed" "$total" "$secs"
      done
    done
  done
done

echo
"$EVALS/summarize.sh" "$results"
echo
echo "artifacts: $out"
