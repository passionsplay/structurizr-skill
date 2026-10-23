#!/usr/bin/env bash
# Summarize a results.tsv as Markdown: pass rate per case and condition, then skill vs baseline.
#
# Usage: evals/summarize.sh evals/runs/<run-id>/results.tsv

set -euo pipefail

results="${1:?usage: summarize.sh <results.tsv>}"

# Run settings (jobs, timeout) affect `seconds`, so print them with the numbers.
run_txt="$(dirname "$results")/run.txt"
[[ -f "$run_txt" ]] && { echo "Run: $(cat "$run_txt")"; echo; }

awk -F'\t' '
  NR == 1 { next }
  {
    key = $1 "\t" $3 "\t" $4
    n[key]++; p[key] += $6; secs[key] += $8
    if (!(key in seen)) { seen[key] = 1; order[++rows] = key }
    split($10, kv, ";")
    for (i in kv) if (split(kv[i], m, "=") == 2) {
      if (m[1] == "inspect_findings")  { insp[key] += m[2]; ni[key]++ }
      if (m[1] == "tech_coverage_pct") { tech[key] += m[2]; nt[key]++ }
      if (m[1] == "cost_usd")          { cost[key] += m[2]; mcost[$3 "\t" $4] += m[2]; total_cost += m[2] }
      if (m[1] == "tokens")            { tok[key] += m[2]; total_tok += m[2] }
    }
    mk = $3 "\t" $4; mn[mk]++; mp[mk] += $6
    if (!(mk in mseen)) { mseen[mk] = 1; morder[++mrows] = mk }
  }
  END {
    print "| case | model | cond | pass | all k passed | avg inspect findings | avg tech coverage % | avg seconds | cost $ | tokens |"
    print "|---|---|---|---|---|---|---|---|---|---|"
    for (r = 1; r <= rows; r++) {
      key = order[r]; split(key, f, "\t")
      printf "| %s | %s | %s | %d/%d | %s | %s | %s | %d | %.4f | %d |\n", f[1], f[2], f[3], p[key], n[key],
        (p[key] == n[key] ? "yes" : "no"),
        (ni[key] ? sprintf("%.1f", insp[key] / ni[key]) : "-"),
        (nt[key] ? sprintf("%.0f", tech[key] / nt[key]) : "-"),
        secs[key] / n[key], cost[key], tok[key]
    }
    print ""
    print "| model | cond | pass rate | cost $ |"
    print "|---|---|---|---|"
    for (r = 1; r <= mrows; r++) {
      mk = morder[r]; split(mk, f, "\t")
      printf "| %s | %s | %d/%d (%.0f%%) | %.4f |\n", f[1], f[2], mp[mk], mn[mk], 100 * mp[mk] / mn[mk], mcost[mk]
    }
    printf "\nTotal: $%.4f across %d trials, %d tokens ($%.4f per trial).\n", total_cost, NR - 1, total_tok, (NR > 1 ? total_cost / (NR - 1) : 0)
  }
' "$results"
