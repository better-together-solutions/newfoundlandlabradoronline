# Documentation standards for NLO changes

NLO follows the Community Engine gem's documentation standard so host-app work backports cleanly.

| Change | Required in the same PR |
|---|---|
| New or changed view, partial, CSS or JS | `spec/docs_screenshots` spec (desktop and mobile, plain and annotated), stable DOM ids, a `spec/dom_contracts` spec, PNGs committed under `docs/screenshots/` and embedded in the PR body |
| New or changed model, association or table | Mermaid source in `docs/diagrams/source`, `bin/export_diagrams` run, exports committed, diagram linked from the feature doc and embedded in the PR body |
| New feature | A short doc under `docs/` (see `docs/regions.md`) with usage, data sources and licences |
| Pure backend change | State "no views or models changed" in the PR |

Tooling: `docs/diagrams/README.md` and `docs/screenshots/README.md`. CI verifies every diagram source renders and has committed exports.
Embed artifacts in a PR body with management-tool `scripts/gh_artifact_embed.py append`.
