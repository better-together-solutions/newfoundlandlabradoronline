# Diagrams

Mermaid sources live in `docs/diagrams/source/*.mmd`; PNG and SVG exports are committed in `docs/diagrams/exports/{png,svg}/`.
Same layout and renderer as the Community Engine gem (`bin/render_diagrams`, see `docs/diagram_rendering.md`).

## Regenerate

```bash
bin/export_diagrams          # refresh generated sources from Rails reflections, then render everything
bin/render_diagrams          # render only (hand-written sources)
bin/render_diagrams --force  # re-render all
```

Rendering needs `mmdc` (mermaid-cli) or `npx`. CI (`.github/workflows/diagrams.yml`) renders every source and fails if an export is not committed (SVG bytes vary between renders, so content is not diffed).

## Sources

| Source | Kind | Shows |
|---|---|---|
| `nlo_regions_schema_erd.mmd` | generated (`scripts/export_diagrams.rb`) | `region_versions` and `region_identifiers` beside `better_together_geography_regions` |
| `nlo_district_page_layers.mmd` | hand-written | request, controller, policy, models, map and PostGIS layers of the district page |
| `nlo_district_load_flow.mmd` | hand-written | source dataset to loader to versioned boundary |

Generated inventory: `docs/diagrams/reference/nlo_schema_inventory.md`. Add a model or table to `MODELS` in
`scripts/export_diagrams.rb` when NLO adds one.

## Rule

A PR that changes a model, association or table updates or adds a diagram, renders it, commits the exports, and embeds the PNGs in the PR body.
