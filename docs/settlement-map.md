# Settlement map

Built on CE's map classes (see `docs/mapping-system-assessment-20261015.md` in management-tool): `SettlementMap <
BetterTogether::Geography::LocatableMap` (host STI subtype, unsaved, with `SettlementMapPolicy` and `settlement_map`
helper), points from each located record's `located_leaflet_point`, rendered by CE's `shared/_map` partial and
`better_together--map` controller. The listing maps on the settlement, region, country, state and continent indexes are
host overrides of CE's `_index_extra` hook partials; nothing from CE's map layer is copied into this app.

Everything below about data, types and limits still holds; the standalone controller and service it once described are
gone.

The settlement page shows a map above the tabs: the settlement pin, its boundary when one is stored, and every
located record inside the settlement that has coordinates of its own. Data comes from
`NewfoundlandLabradorOnline::SettlementMap`, the view is `newfoundland_labrador_online/settlements/_map`, the
behaviour is the `settlement-map` Stimulus controller.

## What is on the map

- **Pin**: the settlement's own geocoded space (latitude and longitude).
- **Boundary**: `Geography::Space#boundary` (multi polygon), simplified in SQL. Corner Brook has a pin but no stored
  boundary yet, so none is drawn until one is loaded (for example from Nominatim polygon output through the
  geocoding job).
- **Items**: records of every model in `LocatableModels` that are located at a geocoded address or building inside the
  settlement (`located_in`), through the viewer's policy scope. Records located at the settlement itself are the pin
  and are not repeated. A model onboarded in `LocatableModels` appears automatically; its colour and icon come from
  the entry's `map:` option.
- Posts that only inherit their community's location have no coordinates of their own and are not shown.

## Boundary credit (decision D3)

OpenStreetMap-derived boundaries stay in this host app, never in the CE gem's boundary packet, and are credited
wherever they are drawn. The credit is one short link (source and licence together, for example "Boundary:
OpenStreetMap (ODbL)") shown in Leaflet's attribution control only. Electoral district boundaries use the same one-link form, "NL Electoral Boundaries
Commission (OGL-NL)", from the `nl_electoral_boundaries` map layer; the full authority and licence are on the district
page.

- `Geography::BoundaryCredit` builds the credit: districts from the region version (authority, source URL, licence),
  settlements from the space's `metadata['boundary_source']` (`osm_type` and `osm_id`). With no recorded source nothing
  is credited, so a missing credit means the provenance is missing.
- Backfill for a boundary stored before provenance was recorded: `bin/rails nlo:regions:backfill_boundary_provenance
  SETTLEMENT=<identifier> OSM_TYPE=relation OSM_ID=<id>` (dry run; add `APPLY=1` to write). It only fills a boundary
  with no recorded OSM source and only from the object you name. Run it on staging data first; on production it is a
  data write that needs its own approval.
- Before loading any new boundary source (Natural Earth, geoBoundaries, Statistics Canada files) check and record its
  licence. That check has not been done yet.

## Types and density

Each type has its own colour and Font Awesome icon (`LocatableModels::ONBOARDED[...][:map]`). Pins are clustered by
density; a cluster icon is a pie of the child types around the count, so mixed clusters read at a glance. The legend
below the map has one checkbox per type present and shows or hides that type (the clusters recompute).

## Plugin choice (assessed 2026-10-14 from the npm registry and OSV)

| Option | Latest | Last release | Known vulnerabilities | Verdict |
|---|---|---|---|---|
| Leaflet.markercluster | 1.5.3 (MIT) | 2021-10 | none | **Used.** Feature complete (cluster icon callback, spiderfy, bulk add and remove), tiny, MIT. Not actively released, so it is vendored and pinned, with a two line change to the UMD wrapper documented in the file header |
| Leaflet.FeatureGroup.SubGroup, MarkerCluster.LayerSupport | 1.0.2, 2.0.1 | 2017, 2018 | none | Not used. They add layer-control toggling that the legend does in ten lines, and are abandoned |
| Supercluster | 9.1.0 (ISC) | 2026-09 | none | Actively maintained clustering index, not a Leaflet layer. The upgrade path if points reach the tens of thousands or Leaflet is replaced |
| PruneCluster | deprecated | | | Category aware but deprecated |
| Leaflet itself | 1.9.4 (BSD-2) | 2023-05 | none | Maintenance mode for 1.x; CE owns this dependency |

The plugin file is `app/javascript/vendor/leaflet.markercluster.js` (npm tarball checksum verified against the
registry), its licence sits beside it, and `leaflet_extensible.js` gives it a plain extensible `L` because CE's global
can be a sealed module namespace. Scripts are served from this origin, so no CSP change is needed.

## Limits

500 items per type. Items inside the stored boundary but not placed in the settlement by the address hierarchy
resolver are not found yet; run the hierarchy resolution or add a containment query when boundaries exist.
