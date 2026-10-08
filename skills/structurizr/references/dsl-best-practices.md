# Structurizr DSL best practices

Lessons from real modeling sessions. Each rule exists because breaking it caused a concrete failure or an unhelpful diagram.

## Identifiers: flat by default

Hierarchical identifiers (`!identifiers hierarchical`, then `webapp.api.authController`) require every reference to spell out the full path, and mistakes produce the same "element does not exist" error as a typo. Flat identifiers (`authController`) are simpler and validate on the first try more often.

Use hierarchical identifiers only when two elements would otherwise need the same name (for example, two systems that each have an `api` container). With flat identifiers every identifier must be unique across the whole model.

## Declaration order

The DSL is parsed top to bottom. An element must be declared before any relationship that references it. Put cross-container component relationships (for example `spa -> authController`) after the closing brace of the system that contains both, not inside the first container.

## Relationships at two levels

The container view should show `spa -> api`. The component view of `api` only becomes useful if it also shows which components the SPA calls:

```dsl
spa -> api "Makes API calls to" "HTTPS/JSON"
spa -> authController "Signs in, refreshes tokens" "HTTPS/JSON"
spa -> userController "Reads and updates profile" "HTTPS/JSON"
```

Do the same for external systems: `oauthClient -> googleOAuth` shows where in the codebase an integration lives, which is what you need when the external API changes.

## Descriptions and technology

- Descriptions are verb phrases from the source's point of view: "Reads orders from", "Publishes events to". Avoid "Uses" and "Calls".
- Technology answers "what would I edit or configure?": "Express Router", "TypeORM", "Kafka topic orders.v1", "PostgreSQL 16".
- Between components in the same container, `"In-process call"` is an honest technology.

## Granularity

Model controllers/routers, services, repositories, and clients for external systems. Do not model individual functions, middleware, or DTOs (too fine), or "Business Logic Layer" (too coarse). If a component can't be described in one sentence, split it or make it more specific.

## Views

`include *` with `autolayout lr` is the right default for context, container, and component views. For crowded component views, filter by tag:

```dsl
component api "ApiControllers" {
    include element.tag==Controller
    include spa database
    autolayout lr
}
```

## Styling

Tag external systems `"External"` and databases `"Database"` and style the tags (grey; `shape cylinder`). Keep a single `styles` block. The template in `assets/workspace-template.dsl` has a sensible default.

## Groups

`group "Name" { ... }` visually clusters related elements (for example, third-party identity providers). Groups don't change identifiers.
