# Civic roles: migrating the deployed model, data and UI

Status: PLAN for review, nothing built. Replaces design phases 2 and 3 for now (instruments and rules, and the election
reference model, are deferred until needed). Builds on phase 1 (PR #215). Design: `docs/civic-roles-membership-design.md`.

## Goal

Everything live today (districts, parties, elections, MHAs, party changes, member names on every page) reads and writes
the new model: Person memberships in communities, with mandates. Then the old tables are retired. Visible behaviour stays
the same, plus the new history and roster views the model makes possible.

## What exists now (production, same shape as dev: 160 terms, 84 party memberships, 5 parties, 488 candidacies, 4 elections)

| Today | Becomes |
|---|---|
| `political_parties` (name, colour, logo, jurisdiction, province) | A `PartyCommunity` per party. `political_parties` stays as the party's detail record (logo, colour, short name) with a new `community_id` FK, so logos and attachments do not move |
| `party_memberships` (person, party, dates, start and end reason, source) | Person membership in the party community, role `party_member`, dated, with a mandate carrying the reasons and source |
| `elected_terms` (person, district, election, candidacy, dates, end reason) | Person membership in the provincial legislature community, role `legislature_member`, dated, with an `elected` mandate: seat = the district, conferred by = the candidacy, end reason mapped |
| (none) | One `LegislatureCommunity` per province legislature (NL: House of Assembly) with a `LegislatureDetail` (provincial, jurisdiction = the NL state, 40 seats, "MHA") |
| `candidacies`, `electoral_contests`, `elections` | Unchanged for now. Candidacies become the mandate's `conferred_by`; elections move to the reference model only when needed |

Added to phase 1 tables: `political_parties.community_id`; `membership_mandates.source_url` and `start_reason` (party
membership reasons and sources); a mandate kind `member` for party membership. All migrations idempotent and reversible.

## Work breakdown

### A. Schema and write path (no behaviour change yet)

1. Migration: the three columns above, plus unique indexes that make the backfill idempotent (one mandate per
   candidacy; one party community per party).
2. `Civic::PartyCommunityLinker` and `Civic::LegislatureProvisioner`: create the communities (public, `host: false`,
   identifiers like `nl-house-of-assembly`, `party-nl-pc`), the legislature detail, and the link from each party. Idempotent.
3. Loaders write the new model: `ProvincialElectionLoader` (terms become memberships and mandates, `close_terms` ends
   them, `build_memberships` creates party memberships), `PartyChangeLoader` (floor crossings end and start party
   memberships), `PoliticalPartyLoader` (provisions the community). Loader specs are rewritten to assert the new records.
4. Rake: `nlo:civic:seed_roles` (exists), `nlo:civic:provision` (communities) and `nlo:civic:backfill` (dry run by
   default, `WRITE=1` to apply): converts every `ElectedTerm` and `PartyMembership` with `skip_notifications` and
   `skip_eligibility`, local-midnight dates in `America/St_Johns`, end reasons mapped (`next_election` to `term_ended`,
   defeat, resignation and so on), logging each record.
5. `Civic::ParityReport` (rake `nlo:civic:parity`): compares old and new for current member per district, party of each
   member on every term start, seats per party now, seats per election per party, party rosters (current and former),
   and per-person term counts. Exits non-zero on any difference.

### B. Read switch (UI)

6. Query layer `Civic::Roster` (one place, used by every controller): current and historical members of a district,
   current seats per party (party derived from the dated party membership on a date), party rosters, members per
   election and contest, a person's terms grouped into consecutive same-seat holdings. Preloads keep the existing query budgets.
7. Replace the `ElectedTerm` and `PartyMembership` reads in `DistrictsController`, `PartiesController`,
   `ElectionsController`, `StatesController`, `ProvinceScoped`, `DistrictsHelper`, and the views (`districts/*`,
   `parties/*`, `elections/show`) with the roster layer. Region and Person concerns stop carrying `elected_terms` and
   `party_memberships` once nothing reads them.
8. UI that the new model adds, kept small:
   - District page: the member history groups re-elections of the same person into one entry ("2015 to now, 3 terms").
   - Party page: current and former members from dated party memberships (as now) with floor-crossing reasons and sources.
   - Legislature page at `/e/members/provincial/:province`: all sitting members by district and party, with former
     members; the province page links to it. This is the first user of the legislature community.
   - Member names keep the CE mention partial (photo and link). Whether a member's own profile page lists their
     offices is decided in the pre-deploy check below.
9. Specs and evidence: DOM contract specs updated, the existing districts, party, election, province screenshots
   recaptured and compared with today's (they must not change), new screenshots for the legislature page and the grouped
   history (desktop and mobile, plain and annotated, opened and checked), diagrams refreshed (`nlo_civic_roles_schema_erd`,
   district page layers, route map, and a migration flow diagram).

### C. Retire the old tables (after parity passes in production)

10. Migration dropping `elected_terms` and `party_memberships` and the `political_party_id` columns on elected terms and
    candidacies, models and associations removed, specs cleaned. Reversible down recreates the tables empty with a
    note that data restores from the snapshot.

## Pre-deploy checks (open items from the design, closed before any deploy)

- Privacy ceiling for new public communities in production, and what CE shows for them: communities index, search, navigation, and
  person profile membership lists. Decide what is hidden. Run in a production clone with the dev app first.
- `default_member_role` and subtype routes in production (covered by specs, confirmed on the clone).
- Contact and notification side effects: backfill sends nothing (verified by spec).
- Query counts on every listing page stay within the existing budgets.

## Deploy sequence (gated by tests and the parity report, not by waiting periods)

1. DB snapshot (first data-model deploy of the series, with restore command), then deploy A: phase 1 plus steps 1 to 5. Reads
   are still the old tables. Run `nlo:civic:seed_roles`, `provision`, `backfill`, `parity` in production. Each is a
   `dokku run` write, so each needs your explicit go-ahead (T3). Parity must be clean.
2. Deploy B: read switch and new UI (steps 6 to 9), after verifying every page in production against the screenshots.
3. Deploy C: retire the old tables (step 10) once pages have been checked on B and you confirm.
Each deploy follows the ce-deployment skill: T3 approval, serialised on bts-5, stale `.upcoming` container check, page checks.
Rollback: deploy A is additive (revert the code, tables stay unused); B reverts by redeploying A's commit; C is the only
step needing the snapshot.

## Order of work and checkpoints (review gate after each)

1. Steps 1 to 3 (schema, provisioning, loaders), specs, commit.
2. Steps 4 and 5 (backfill and parity) run against the dev copy of production data; commit.
3. Steps 6 and 7 (roster layer, controllers and views), specs, commit.
4. Step 8 and 9 (new UI, screenshots, diagrams), commit and push. Then the deploys above, each on your go-ahead.
5. Step 10 on its own branch after B is verified.

## Risks

- Behaviour drift: guarded by the parity report and unchanged screenshots.
- Party on a date: today derived from `party_memberships`; the new derivation must give the same answer on every
  term start, which the parity report checks explicitly.
- Public exposure of new communities and member lists through CE surfaces not built by us: checked before deploy A.
- `skip_eligibility` bypass is used only by the backfill and loaders, logged per record.
- Dropping tables is irreversible without the snapshot: separate deploy and confirmation.

## Decisions for you

1. Branch: continue on `feat/civic-roles-foundation` (PR #215) so one PR carries migration plus UI, or stack new branches per checkpoint. I recommend continuing on #215, as the phase 1 code is unused without this work.
2. Legislature page: build it now (recommended, it is the visible payoff of the legislature community), or defer.
3. Old tables: drop in deploy C (recommended) or keep read-only for an extended period.
4. Hide the new communities from the general CE communities index and search until you want them listed (recommended pending the privacy check), or list them.
