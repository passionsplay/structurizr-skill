# Evals

Measures whether the structurizr skill helps an agent, by running the same tasks with the skill loaded (`skill`) and without it (`baseline`) and grading the results with deterministic checks. The skill's value is the difference between the two pass rates.

Dev-only: `npx skills add` installs only `skills/structurizr/`, so nothing here ships to users.

## Run

```bash
evals/run.sh -m openrouter/~deepseek/deepseek-v4-flash-latest           # all cases, both conditions, 1 trial
evals/run.sh -m <model> -c fix-forward-reference -k 3                    # one case, 3 trials for pass^k
evals/run.sh -m <model-a> -m <model-b> -C skill                          # compare models with the skill only
evals/run.sh -m <model> -k 3 -j 4                                         # 4 trials at a time
```

Needs Docker, `jq`, `timeout`, and `pi` on the host (only for its stored OpenRouter credential; set `OPENROUTER_API_KEY` instead if you prefer). Each trial runs in a fresh temp dir inside a container built from `docker/Dockerfile` (the first run builds it): `pi`, bash, `jq`, `curl`, and a Docker client, with no Java, no repo, and none of your home directory. The container reaches the host Docker daemon through its socket, which is how the skill's script runs Structurizr, so this isolates the filesystem but is not a sandbox against a hostile agent. `-a pi` runs `pi` directly on the host instead, which the first results showed leaks host tools into the baseline. Artifacts (prompt, JSON transcript, grade, the agent's files) land in `evals/runs/<run-id>/`, which is gitignored. Copy a run's summary table into `results/` when it is worth keeping, for example before a release.

`-j N` runs N trials at once. It pays off once each Structurizr call is cheap: before the script cached the unpacked image, every `validate`, `inspect`, and `export` was a CPU-bound JVM start of about 30s and `-j 4` gained nothing on a 6-CPU Docker VM; with the cache, a full k=3 run took 12 minutes at `-j 4` against about 1h45m sequential (2026-10-26). Parallel trials still share CPU, so `seconds` is only comparable between runs with the same `-j`, and slow trials near the timeout can tip over it. The summary prints the run's `jobs` and `timeout`. Use `-j 1` for numbers you quote. Ctrl-C stops all running trials and removes their containers.

Models that come from a pi extension only work with `-a pi`, which can load one explicitly: `PI_EXTENSIONS=<path/to/extension.js> evals/run.sh -a pi -m <provider/model>`.

## Layout

- `cases/<name>/prompt.md`: the task, written the way a user would ask. The runner appends a note telling the agent nobody can answer questions.
- `cases/<name>/setup/`: optional starting files copied into the work dir.
- `cases/<name>/check.sh`: grading. Prints `PASS`/`FAIL <gate>` lines (a trial passes only if every gate passes) and `METRIC <name> <value>` lines (tracked, never pass/fail).
- `lib/grade.sh`: shared checks. They export the workspace to JSON with the real Structurizr image and query the parsed model with `jq`, rather than grepping the DSL.
- `docker/Dockerfile`: the trial image.
- `agents/<name>.sh`: one adapter per agent CLI. Contract: `<model> <skill|baseline> <prompt-file>`, run in the work dir, transcript to stdout.
- `results/`: committed summaries.

## Cases

| Case | Tests | Gates beyond "validates" |
|---|---|---|
| `create-webapp` | Model from scratch | context + container views, Google and SendGrid modeled |
| `extend-existing` | Change a model without breaking it | Redis added, component view with 4+ components, originals kept |
| `fix-forward-reference` | Repair the most common DSL error | nothing removed |
| `export-mermaid` | Tool use | one `.mmd` per view, workspace untouched |
| `component-store` | The cross-container component rule | SPA → component relationship, Stripe modeled |

Metrics on every trial: `inspect_findings` (C4 quality, lower is better), `tech_coverage_pct` (relationships that name a technology), `validate_calls` (shell commands the agent ran that contain `validate`, a signal that it checked its own work), `cost_usd` and `tokens` (as reported by the agent CLI). Quality metrics are blank when the workspace does not validate.

## Adding a case

Write the prompt first, then the checks, then test the checks before trusting them: run `check.sh` by hand against a known-good and a known-bad workspace and confirm the gates split the way you expect. A grader that passes everything measures nothing.
