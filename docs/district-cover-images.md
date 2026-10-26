# District cover and card images

Status: design only, nothing implemented in app code. Prototype: `tmp/district-covers/render_district_cover.py`
with samples for `nl-ped-corner-brook` in `tmp/district-covers/`.

## Problem

Area-based districts (provincial electoral districts, later federal ridings, regions) show CE's default
cover and card image. Each one has a boundary polygon in `RegionVersion#boundary`, so we can draw a
real, recognisable image of the area.

## What already exists

- Ship tracker renderer: `scripts/traffic_bay_map.py` in management-tool (matplotlib + Pillow). It does NOT
  use raster tiles. It draws a vector map from an Overpass extract cached in `data/geo/humber_arm_osm.json`,
  hard-wired to Humber Arm (bbox constants, coastline chain clipping). Reusable ideas: `_fit_bbox` aspect
  fitting, `_save_jpeg` size cap (700 KB, quality ladder), the "(c) OpenStreetMap contributors" caption on
  every image, cover and embedded copy of the same render. Not reusable as is: the base layer, vessel code,
  and the fact it lives in a Python repo, not the Rails app.
- Ship posts attach the render as `cover_image_path` and also list it in `images` (embedded in the body), which
  matches the rule that covers must also be embedded. Publishing is through the management-tool publisher,
  not NLO app code.
- Site map layer: CE `better_together/map_controller.js` uses `L.tileLayer.provider('OpenStreetMap.Mapnik')`
  (https://tile.openstreetmap.org/{z}/{x}/{y}.png, Leaflet-providers attribution) plus an Esri satellite
  option, `fitBounds` with 50px padding. District overlays come from NLO `party_overlay_controller.js`:
  `L.geoJSON` with `weight: 1.5`, `fillOpacity: 0.45`, colour = sitting member's party colour (fallback
  `PoliticalParty::FALLBACK_COLOR`), boundary simplified with `ST_SimplifyPreserveTopology(..., 0.002)`.

## Prototype findings

- Mapnik raster tiles + Pillow only (no new gems; shapely not needed). Fractional zoom fit to bbox with 12 percent
  padding, tiles fetched at the next integer zoom and resampled, boundary drawn 3x supersampled.
- Corner Brook fit zoom 12.8, 45 tiles for the 1600x900 cover, 15 tiles for 800x450. Total 60 requests, one at
  a time with a 1 s pause, then fully cached. Real use should render the card from the cover tiles (downscale
  the cover) so a district costs about 45 tiles once.
- Variants: `leaflet` (matches site layer: party-blue outline, 0.45 fill) and `muted` (white wash on the basemap,
  thicker dark outline, 0.30 fill; better for text overlays on cards).
- Weaknesses seen: very large northern districts fit at low zoom where Mapnik is sparse; many Labrador
  districts will need zoom 6 to 8 and will look empty. Thin coastal boundaries can cover water edges.

## Licensing and policy

- OSM tile usage policy (operations.osmfoundation.org/policies/tiles): needs a real identifying User-Agent
  (not a library default), cache honouring expiry, no bulk or offline pre-fetch, heavy use discouraged. Rendering
  about 40 districts once, cached, is small, but a full province plus regeneration needs care.
- Data: tiles are ODbL derived; attribution "(c) OpenStreetMap contributors" must be visible on the image itself
  (it is baked in) and preferably also in the page caption linking to openstreetmap.org/copyright. Do not rely on
  alt text.
- Boundary data licence: carry the boundary version's `license` and `authority` into the image caption or the
  block attribution field (NLO `image_block` already supports `attribution` and `attribution_url`).
- Safer option if volume grows: a self-hosted or commercial tile source (the geo-stack plan, docs in
  management-tool `docs/geo-stack-plan-20261013.md`, already considers self-hosting), or MapLibre vector
  rendering from our own extract like the ship maps. The renderer takes a tile URL template so this is a config change.

## Proposed design

Service `NewfoundlandLabradorOnline::Geography::DistrictCoverRenderer` (ruby, mini_magick or vips is already in
the CE image stack; confirm which) with a small tile fetcher:

1. Input: `RegionVersion` (current), style (`:leaflet`, `:muted`), size (`:cover` 1600x900, `:card` 800x450).
2. Boundary: GeoJSON via PostGIS, simplified to about 0.0002 deg for drawing (the page overlay uses 0.002).
3. Tile fetch: `TileCache` backed by `Rails.root/storage/tile-cache` (persistent volume, not tmp), key z/x/y, TTL 7
   days minimum, User-Agent `NLO-district-covers/1 (+https://newfoundlandlabrador.online; contact address)`,
   serial requests, 1 s pause, hard cap per run (for example 120 tiles) and a global kill switch.
4. Output: JPEG capped near 300 KB for cover, with attribution baked in. Deterministic bytes for a given input.
5. Attach: `ActiveStorage` `cover_image` (CE `Cover`) plus a custom marker so we know it is generated, and
   append an NLO image block with caption and attribution link to the district page body so the cover is also
   embedded (rule: covers must also be embedded). Card image reuses the same cover attachment resized by variants,
   or a separate `card_image` if CE exposes one. Never overwrite an editor-uploaded cover: record `generated: true`
   in blob metadata and skip districts whose cover is not generated.
6. Regeneration: a job `DistrictCoverJob` enqueued from `RegionVersion` after_commit when `boundary` changes or a
   new current version is set. Store the boundary checksum (`ST_MD5` or hash of the GeoJSON) in blob metadata and
   skip when unchanged. Party colour changes do not regenerate (the leaflet variant uses a neutral blue, or colour
   is opt-in).
7. Rake task `nlo:districts:covers[scope,--dry-run]` for backfill with a rate limit, mirroring existing
   `nlo_civic.rake` conventions, with `--dry-run` and explicit write enable.

## Tests

- Unit: tile math (lat/lon to pixel, zoom fit) against known values; bbox padding; multipolygon and holes.
- Renderer with a stubbed tile fetcher serving a solid-colour PNG: image has requested size, attribution pixels
  present, byte cap respected, deterministic output.
- Cache: second render makes zero HTTP calls (WebMock); User-Agent header present on every request; cap and kill
  switch stop fetching.
- Job: skipped when checksum unchanged, skipped when cover is editor-uploaded, enqueued on boundary change.
- View contract (DOM id spec): district page contains the embedded map image block with attribution link.
  Per repo rules a view change also needs docs screenshots.

## Implementation plan

1. Decide tile source (open questions below) and library (vips or mini_magick).
2. Port the prototype into the renderer service plus `TileCache`, specs with stubbed tiles.
3. Dev backfill on a few districts, review images with Rob (include a large Labrador district).
4. Add job, checksum, attach cover and embedded block; DOM contract spec and screenshots.
5. Rake backfill for all provincial districts, single run, then monitor request counts.
6. Extend to federal ridings and other area types by passing any region version.

## Open questions

- Is OSM Mapnik acceptable long term, or move to self-hosted tiles or vector rendering for large areas?
- Neutral blue or party colour for the outline? Party colour changes would force regeneration.
- Which image library does the NLO image support (vips vs mini_magick), and does CE expose a separate card image?
- For huge, sparse districts, should we add an inset locator map of the province?
- Should an editor-uploaded cover always win (proposed yes)?

## Decisions (2026-10-20)

- Boundary style matches the party-branded Leaflet overlay: party colour stroke, 0.45 fill.
- Party comes from the latest provincial election: the elected candidacy's party in that district. Fallback colour `#6c757d` when none.
- The generated cover is attached to the district's own `cover_image` (the attachment a manual upload uses, so an upload replaces it and the card image follows).
- A second attachment, `default_cover_image`, keeps the generated image so it can be restored when a custom cover is cleared.
- Image library: Pillow, as in the ship tracker scripts (`scripts/traffic_bay_map.py`).
- Locator inset: province overview bottom-left, with district filled in party colour. Variants prototyped: `inset-map` (OSM tiles) and `inset-outline` (vector only). Prototype files are in `tmp/district-covers/v2/`.

## Built (2026-10-20)

Pipeline, run on bts-0 with the NLO app only touched at the two ends:

1. `rake nlo:regions:cover_inputs OUT=tmp/district-covers/inputs.json` writes boundaries, credit and colour per district.
   Colour is the sitting member's current party (Independent and vacant seats are grey), as on the live map.
2. `scripts/district_cover_images.py --input inputs.json --out DIR [--only NAME ...]` (management-tool, Pillow) writes
   one `nl-ped-<slug>.jpg` per district (1200x675, under 700 KB) plus `manifest.json`. OSM tiles are cached under
   `tmp/district-cover-tiles` and fetched one per second with a named User-Agent; run it on a few districts at a time.
3. `rake nlo:regions:attach_covers DIR=... [WRITE=1]` (dry run without WRITE) attaches each JPEG to the district's
   district as `default_cover_image`, and as `cover_image` unless someone uploaded their own.

Clearing the cover on a district restores the stored default (`BetterTogether::DefaultCoverImage`).
The district page shows the cover above the title (like the settlement page) and the district cards use it as their card image.
