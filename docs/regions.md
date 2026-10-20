# Typed regions, versions and identifiers

Host-side first cut (to be backported to Community Engine). Plan and data sources: management-tool
`docs/nl-regions-electoral-census-assessment-20261019.md`.

```mermaid
erDiagram
  REGION ||--o{ REGION_VERSION : "has (valid_from/valid_to)"
  REGION ||--o{ REGION_IDENTIFIER : "has (scheme, value)"
  REGION ||--o| GEOSPATIAL_SPACE : "cached boundary + point"
  REGION { uuid id  string type  string identifier }
  REGION_VERSION { string name  date valid_from  date valid_to  geography boundary  string authority  string source_sha256 }
  REGION_IDENTIFIER { string scheme  string value }
```

- `Region` keeps one identity across redistributions. `NewfoundlandLabradorOnline::ProvincialElectoralDistrict` is an STI
  subtype (identifier `nl-ped-<slug>`).
- `RegionVersion` (`region_versions`) stores the name and boundary in force over a date range. `region.version_on(date)`
  and `region.current_version` resolve it. The region's `Space#boundary` caches the current version for placement.
- `RegionIdentifier` (`region_identifiers`) holds external ids, unique per scheme (`nlo_ped`, `statcan_dguid`,
  `statcan_feduid`, `wikidata`, `osm_relation`, `elections_nl`).

## Loading the 40 districts (2015 map)

`bin/rails nlo:regions:load_provincial_districts` reads `db/data/nl_regions/provincial_electoral_districts_2015.geojson`
(Open Data NL dataset 361, Open Government Licence; simplified to about 70 m). Idempotent: districts match on their
`nlo_ped` identifier, and a version's boundary is rewritten only when the packet's `source_sha256` changes.

The packet is built by management-tool `scripts/nl_regions_ingest.py` (`fetch-districts`, `build-districts`).

## Public district pages

- `GET /:locale/e/districts/provincial` lists the districts; `GET /:locale/e/districts/provincial/:id` (for example `/en/e/districts/provincial/nl-ped-corner-brook`)
  shows the current boundary on the shared map, facts and source, settlements whose point falls inside the boundary, the
  history of names and boundaries, and external identifiers. Both are public; policy is `ProvincialElectoralDistrictPolicy`.
- Stable DOM ids are asserted in `spec/dom_contracts/district_page_spec.rb`.
- Screenshots (desktop and mobile, plain and annotated) are captured with
  `./bin/dc-run env RUN_DOCS_SCREENSHOTS=1 bundle exec rspec spec/docs_screenshots/districts_spec.rb` into `docs/screenshots/`.

![District page, desktop](screenshots/desktop/district_show_annotated.png)
![District page, mobile](screenshots/mobile/district_show.png)

## Diagrams

Sources in `docs/diagrams/source`, exports in `docs/diagrams/exports` (see `docs/diagrams/README.md`).

![Schema ERD](diagrams/exports/png/nlo_regions_schema_erd.png)
![District page layers](diagrams/exports/png/nlo_district_page_layers.png)
![District load flow](diagrams/exports/png/nlo_district_load_flow.png)

## Elections and members (phase 2)

Provincial general-election results for 2015, 2019, 2021 and 2025 load from `db/data/nl_regions/provincial_election_results.json`
(built by management-tool `scripts/nl_elections_ingest.py` from Wikipedia, with source URL, revision id and checksum on
each election; cross-check against Elections NL before relying on a figure).

```bash
./bin/dc-run bin/rails nlo:regions:load_provincial_elections   # idempotent; run after load_provincial_districts
```

- `elections` holds one row per general election; `electoral_contests` one per district per election;
  `candidacies` the candidates (names only).
- Only elected candidates become `BetterTogether::Person` records (identifier `nl-mha-<name>`), joined to the district
  and election cycle by `elected_terms`. A term ends when the next election's winner takes the seat.
- By-elections and mid-term resignations are not loaded yet.

### Parties, brand colours and affiliation over time

Parties load first from `db/data/nl_regions/provincial_parties.json` (built by management-tool
`scripts/nl_parties_ingest.py`; logos in `db/data/nl_regions/party_logos/`):

```bash
./bin/dc-run bin/rails nlo:regions:load_political_parties   # idempotent; run before load_provincial_elections
```

- `political_parties` are scoped by `jurisdiction` (`provincial`) and `state_id`. Provincial and federal parties are separate
  entities even when they share a name: the provincial Liberals and NDP are not their federal counterparts. The
  association between them (same organisation, affiliated, or unrelated) is modelled with the federal electoral work.
- The brand colour is derived from the logo (SVG fills or dominant saturated pixels), falling back to Wikipedia's
  chart colour, then a neutral grey; `color_source` records which. Logo licence and source are stored per party.
  The PC and NL Alliance logos are Wikipedia fair-use (non-free): confirm permission before public production use.
- `party_memberships` are dated rows (`started_on`, `ended_on`, start and end reasons such as `elected`,
  `floor_crossing`) so a member can change party mid-term. The loader seeds one per run of terms in the party elected;
  `ElectedTerm#party_on(date)` answers from the membership in force, else the party elected.
- The districts map fills each district in its sitting member's party colour (no member: grey) with a legend and
  seat counts; the district page shows the member's party swatch and logo.
- Floor crossings come from the official House of Assembly "History of the Standings" page, parsed by management-tool
  `scripts/nl_assembly_ingest.py` into `db/data/nl_regions/provincial_party_changes.json` (which also carries the current
  roster). The roster is a static script file, so plain HTTP works and no browser crawler is needed.

```bash
./bin/dc-run bin/rails nlo:regions:load_party_changes   # after the elections load; idempotent, reports roster mismatches
./bin/dc-run bin/rails nlo:regions:create_districts_nav_item   # public Districts link in the platform header
```
- Diagram: `docs/diagrams/exports/png/nlo_elections_schema_erd.png`.

## Parties, elections, cards and routes

- All election-related pages live under `/e`; districts have one sub-path per district type: `/:locale/e/districts/provincial` (all provinces),
  `/:locale/e/districts/provincial/:province` and `/:locale/e/districts/provincial/:province/:id`.  Federal and
  other provincial district types get their own sub-path later.
- `GET /:locale/e/parties` lists parties with current seats; `GET /:locale/e/parties/:jurisdiction/:province/:identifier` (for example
  `/en/e/parties/provincial/nl/liberal`) shows the logo and licence, current members and former members, each with
  their districts linked back. Every party name on district, results and election pages links here.
- `GET /:locale/e/elections` lists elections with seats by party; `GET /:locale/e/elections/:jurisdiction/:province/:year` shows
  every contest with linked districts and parties.
- District cards (`districts/_card`) wrap CE's `shared/_card`: name, sitting member, party chip, and the cover image
  through `BetterTogether::Attachments::Images` (`attachable_cover_image` on `ProvincialElectoralDistrict`; the card image is
  the cover image). Districts without an image show CE's placeholder.
- Query budget: every page above runs under 70 queries regardless of row count (preloaded translations, memberships,
  attachments); `spec/dom_contracts/party_election_pages_spec.rb` guards it. The listing map's simplified outlines are
  cached for 12 hours and keyed on the spaces' `updated_at`; uncached they cost about 3 s on 40 districts.

## States and provinces

`:province` is the lower-case province code (`nl`, `ns`, ...) and resolves to the geography `State` whose `iso_code` is
`CA-<CODE>`; an unknown code is a 404. Districts (`region.state_id`), parties and elections (`state_id`, migration
`20261020120000`) are associated with their province in the geography tables, and `BetterTogether::Geography::State`
has `provincial_electoral_districts`, `political_parties`, `elections` and `province?` (concern
`NewfoundlandLabradorOnline::State`).

Public state pages follow the settlement pattern under `/g`: `/:locale/g/states` and `/:locale/g/states/:id` (slug or
province code) are canonical for any state; `/:locale/g/provinces` and `/:locale/g/provinces/:id` are the alias used for
states that identify as provinces (the ten `CA-` provinces) and 404 for others. A province page has tabs for its
districts, parties and elections beside its regions and settlements. `StatePolicy` is prepended so index and show are
public, and update/destroy need `manage_platform` (as for settlements).
