# Municipal settlements: status and identifiers

Phase 1 of the municipal data work (plan: management-tool `~/.claude/plans/nlo-municipal-data-plan.md`, source
findings in `tmp/municipal/phase0-findings.md`). A settlement is the single record for a place. Municipal standing and
outside ids hang off it, so a town that was an unincorporated community, became a town and later amalgamated is one
record with a dated history.

![Settlement status and identifier tables](diagrams/exports/png/nlo_settlements_schema_erd.png)

## Dated status

Both tables and models use the Community Engine naming (`better_together_geography_*`, `BetterTogether::Geography::*`,
created with `create_bt_table`), so they can move into the gem unchanged. Only the concern that attaches them to
`Settlement` is host-side.

`BetterTogether::Geography::SettlementStatus` (`better_together_geography_settlement_statuses`) records the standing a settlement held over a date range, with the authority
and source that say so.

| Field | Meaning |
|---|---|
| `municipal_status` | `city`, `town`, `inuit_community_government`, `local_service_district`, `reserve`, `unincorporated` |
| `name` | The name used under this status, when it differs from the settlement's current name |
| `valid_from`, `valid_to` | Dates in force. An empty end means current. An empty start means "not recorded" |
| `authority`, `source_url`, `license` | Who says so and under what licence the record was taken |

`settlement.status_on(date)` and `settlement.current_status` resolve the status in force. When ranges overlap, the one
with the latest `valid_from` wins.

## Identifiers

`BetterTogether::Geography::SettlementIdentifier` (`better_together_geography_settlement_identifiers`) holds external ids, unique per scheme and value, one per scheme per
settlement: `statcan_csd`, `statcan_dguid`, `nl_open_data_gcl`, `wikidata`, `osm_relation`.
`Settlement.with_identifier(scheme, value)` finds a settlement by any of them.

## Boundaries

Settlements keep their boundary on the geography space, with `boundary_source` provenance and the credit described in
`settlement-map.md`. The OSM/Nominatim boundary already stored is the default. Statistics Canada census subdivision
and city GIS boundaries are a follow-up; they will be recorded as a differently sourced boundary, never overwriting a
sourced one without a flag. Open Data NL dataset 265 holds points only, so it supplies names and ids, not shapes.

## Councils and officials (phase 2)

A council is a `LegislatureCommunity` whose `LegislatureDetail` has level `municipal`, the settlement as jurisdiction
and a `body_kind`: `council`, `lsd_committee` (elected local service district committee, no council powers) or
`legislature` (the default, for the House of Assembly). Councils are civic communities, so they stay out of generic
discovery and the sitemap like other civic types.

Offices use the generic legislature roles: `legislature_head` (title "Mayor" or "Chair"), `legislature_deputy_head`
(title "Deputy Mayor") and `legislature_member` (title "Councillor", "Ward 3 Councillor"). A deputy mayor holds both the
deputy role and a councillor role. Wards are `CommunitySeat` records; at-large councillors have no seat.

`Civic::MunicipalCouncil` provisions a council and its seats. `Civic::MunicipalRosterLoader` reads
`db/data/nl_municipal/councils.json` and creates people (one per settlement and name, identifier
`nl-municipal-<settlement>-<name>`) and dated memberships. It also records the settlement's Statistics Canada CSD code
and municipal status. Only names, offices and dates are loaded; no phone numbers or emails.

```bash
bin/dc-run bin/rails nlo:municipal:load_councils            # dry run, rolled back
APPLY=1 bin/dc-run bin/rails nlo:municipal:load_councils    # writes
```

The packet holds Corner Brook (council page, results of 2025-10-02) and St. John's (the city's own council page,
fetched 2026-11-01). Corner Brook start dates are the election date and approximate. St. John's start dates are not
recorded, and its 2025 results are not yet verified against an official notice. A person who is both a councillor and
an MHA has two records for now.

## Municipal elections (phase 3)

The provincial election tables now also hold council contests (diagram: `nlo_elections_schema_erd`).

- `elections` gains `community_id` (the council) and `kind` (general, by_election, plebiscite). Uniqueness is per
  jurisdiction, state, council and date.
- `electoral_contests` gains `office` (member, mayor, councillor), `seats_available` and `community_seat_id`;
  `region_id` is optional for municipal contests, which are unique per election, office and seat.
- `candidacies` gain `acclaimed`; `party_name` and `votes` are optional for municipal candidates (no NL council has
  parties; acclaimed candidates have no votes).
- A contest has `winners` (several for a multi-seat councillor race) and a nil-safe `total_votes`.
- Municipal elections are excluded from the public provincial elections pages, which assume a region per contest.

`MunicipalElectionLoader` reads `db/data/nl_municipal/elections.json`, finds the council by settlement, writes the
election, contests and candidacies, and links each elected candidate to the matching office through
`conferred_by` on the mandate. Elected candidates with no matching office are reported, not guessed.

```bash
bin/dc-run bin/rails nlo:municipal:load_elections            # dry run
APPLY=1 bin/dc-run bin/rails nlo:municipal:load_elections    # writes
```

The packet holds Corner Brook 2025-10-02 (source: cornerbrookvotes.com). St. John's results are not loaded until an
official notice is found. Load councils first.

## Not in this phase

Bylaws, meetings and census data follow in later phases.
