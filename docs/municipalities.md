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

## Not in this phase

Councils, officials, elections, bylaws, meetings and census data follow in later phases.
