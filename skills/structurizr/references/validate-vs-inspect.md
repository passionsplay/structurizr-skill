# validate vs inspect

Two commands, two questions. Users who ask "is this valid?" want `validate`. Users who ask "is this complete?" or "is this a good model?" want `inspect`.

| | `validate` | `inspect` |
|---|---|---|
| Question | Will this parse into a workspace? | Does this follow C4 and Structurizr recommendations? |
| Output on success | Nothing (exit 0) | List of findings, or nothing |
| Output on problems | `ERROR ... at line N of workspace.dsl: <source line>` | One line per finding: `ERROR \| <rule id> \| <message>` |
| Exit code | Non-zero on any error | The number of findings (0 only when there are none) |
| Blocking? | Yes. Nothing renders until it passes. | No. Findings are recommendations. |

## Common validate errors

| Message | Cause | Fix |
|---|---|---|
| `The destination element "x" does not exist` | Typo, missing element, or relationship declared before the element | Check the identifier; move the relationship below the element's definition |
| `The source element "x" does not exist` | Same as above, for the left side | Same |
| `Unexpected tokens` / parse errors | Unbalanced braces or unquoted strings with spaces | Quote every name, description, and technology |

## Common inspect findings

| Rule id | Meaning | Fix |
|---|---|---|
| `workspace.scope` | No workspace scope set | Add `configuration { scope softwaresystem }` (one detailed system) or `scope landscape` |
| `model.relationship.technology` | A relationship has no technology | Add a third string: `a -> b "Calls" "HTTPS/JSON"`; use `"In-process call"` between components |
| `model.relationship.description` | A relationship has no description | Add a verb phrase: `"Reads orders from"` |
| `model.softwaresystem.documentation` | A system with containers has no docs | Optional. Add `!docs <folder>` inside the system with Markdown files, or ignore |
| `model.softwaresystem.decisions` | A system with containers has no ADRs | Optional. Add `!adrs <folder>` with ADR files, or ignore |
| `views.view.key` / `views.view.layout` | A view has an auto-generated key | Give every view an explicit key: `container system "Containers" { ... }` |
| `model.*.description` | An element has no description | Add the description string after the name |

Report inspect findings grouped by rule id with counts, and say which ones are worth fixing. Do not describe the workspace as broken because of them.
