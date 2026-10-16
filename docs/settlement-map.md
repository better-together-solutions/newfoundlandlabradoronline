# Settlement map

Built on CE's map classes (see `docs/mapping-system-assessment-20261015.md` in management-tool): `SettlementMap <
BetterTogether::Geography::LocatableMap` (host STI subtype, unsaved, with `SettlementMapPolicy` and `settlement_map`
helper), points from each located record's `located_leaflet_point`, rendered by CE's `shared/_map` partial and
`better_together--map` controller. Until NLO's CE pin includes community-engine-rails PR #1914, the controller, partial,
styles, vendored clustering plugin and translations are carried here as marked copies (`app/javascript/controllers/
better_together/map_controller.js`, `app/views/better_together/shared/_map.html.erb`, `app/assets/stylesheets/
settlement_map.scss`, `app/javascript/vendor`, `config/importmap.rb`); delete them when the pin moves.

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
