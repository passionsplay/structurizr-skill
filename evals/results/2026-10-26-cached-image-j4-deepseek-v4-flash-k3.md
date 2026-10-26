# 2026-10-26: cached image, -j 4, DeepSeek V4 Flash, k=3

Skill at `ce08cd6` (the unpacked-image cache in `structurizr.sh`), Structurizr image `2026.10.26` (`:latest` moved from 2026.09.19 the same day), agent `pi` 1.1.0 in the trial container, model `openrouter/~deepseek/deepseek-v4-flash-latest`, 5 cases x {skill, baseline} x 3 trials, `-j 4`, 600s timeout. Run id `20261026-151852`.

| case | skill | baseline | avg inspect findings (skill / baseline) | baseline failures |
|---|---|---|---|---|
| create-webapp | 3/3 (22s) | 0/3 (18s) | 4.7 / - | Twice invalid DSL, never validated; once `theme default`, which fails validate because `static.structurizr.com` is gone |
| extend-existing | 3/3 (77s) | 2/3 (183s) | 2.7 / 7.0 | Invalid DSL, never validated |
| component-store | 3/3 (44s) | 0/3 (193s) | 2.0 / 12.0 | Twice valid but no SPA → component relationship; once invalid |
| fix-forward-reference | 3/3 (13s) | 3/3 (49s) | 7.0 / 7.0 | |
| export-mermaid | 3/3 (22s) | 2/3 (167s) | 3.0 / 3.0 | Mermaid files missing or without diagram content |

**Pass rate: skill 15/15, baseline 7/15 (47%).** Seconds are per-trial agent time at `-j 4`; compare them only with other `-j 4` runs.

**Wall time: 11m53s**, against about 1h45m for the sequential k=3 run on 2026-10-23. Agent time per skill trial fell 3-5x (for example `component-store` 115s to 44s), mostly from cheaper `validate` calls.

## Cost

| | skill | baseline | total |
|---|---|---|---|
| pi-reported | $0.0873 | $0.3171 | $0.4045 (5.72M tokens) |
| OpenRouter key usage delta | | | $0.2744 |

pi over-reported again (1.5x). Budget about $0.009 per trial from the OpenRouter number.

## Observations

- The runner printed `avg inspect findings` of 1.0 almost everywhere. Image 2026.10.26 changed `inspect` to exit 1 when there are findings instead of exiting with the count, and the grader read the exit code. The grader now counts the printed finding lines; the table above uses re-computed values. Pass/fail was not affected. This is the case for pinning the image tag (open work).
- New skill gotcha from a baseline failure: `theme default` (and any theme on `static.structurizr.com`) now fails `validate`, since the Structurizr cloud service reached end of life on 30 September 2026. Added to `SKILL.md`.
- `component-store` is the clearest discriminator: the baseline never connected the SPA to components in the API in 3 tries, and averaged 12 inspect findings to the skill's 2.
- `fix-forward-reference` still does not discriminate.
