# Civic roles on CE memberships: design (NLO first)

Status: DRAFT. Phase 1 (foundation) built, see docs/civic-roles.md; later phases not built. Scope: model people's roles in organisations as time-boxed memberships, first for
the House of Assembly, its parties and the cabinet, shaped so councils, boards, committees and departments reuse it.
Diagram: `docs/diagrams/source/nlo_civic_roles_model.mmd`.

## Decisions so far

- One membership per election mandate; re-election is a new membership, and the page groups consecutive same-seat
  holdings for display.
- Election dates are the start and end dates for now (marked approximate); exact dates come later from member pages.
- Cabinet is a separate Community tied to the governing party (or parties) and the legislature session; its roster and
  portfolios change at any time and the history must be shown.
- Departments are Community subtypes. Community subtypes that need attributes get an associated detail record.
- A constituency office belongs to mandates and is shared by consecutive mandates of the same holder and seat.
- Electoral systems are modelled, parties are optional on elections, and coalition governments are supported minimally.
- A child community may not be more public than its parent unless the association is `open`.
- Organisations can be members of other organisations and sit on their boards through representatives (the NLFC case).
- Communities have governing instruments (bylaws, acts) whose rules the system can consult.
- Built in NLO first; CE backport list at the end.

## Principles

- One Person record per human. Every role is a membership of that Person in a Community.
- Almost everything is, or has, a Community. Subtypes use the existing `better_together_communities.type` STI column.
- Dates belong on every membership. Kind-specific detail (seat, source, title) is a separate record with the foreign key
  on the detail side, so ordinary memberships and communities carry nothing unused (the venue community pattern).
- Geography stays geography: a district is a seat held, not a Community.

## Building blocks in the CE gem (pin 929bb51a9492)

| Block | What it gives | Gap |
|---|---|---|
| `PersonCommunityMembership` (member, joinable, role, status) | Person to Community link with a role | No dates; unique on (joinable, member, role) so a role cannot recur; no place or source |
| `Role` (resource_type scoped, resource permissions) | Roles per joinable type; the permission cache joins only roles that have permissions | Roles without permissions are inert, which suits offices |
| `Community` (`type` STI, `Joinable`, `Privacy`, platform ceiling) | Subtype per organisation kind | Ceiling validation applies to each new Community |
| `MembershipNotificationService` | Notifies on create, role change, removal | Must be silent for civic records |

## Model

### Memberships and mandates

NLO migration on `better_together_person_community_memberships` (guarded with `column_exists?`):

| Column | Purpose |
|---|---|
| `starts_at` (datetime, null) | Start of the holding; null for ordinary open-ended memberships |
| `ends_at` (datetime, null) | Exclusive end; null means current |

The unique index becomes (`joinable_id`, `member_id`, `role_id`, `starts_at`), nulls not distinct. A validation in a
prepended concern rejects overlapping holdings of one role. Civic dates are calendar dates in `America/St_Johns`, stored at
local midnight and shown as dates. Active status and the permission cache derive from the dates at read time. A
`skip_notifications` flag, set by loaders, silences imported memberships.

`MembershipMandate` (`membership_mandates`), `belongs_to :membership` (unique), is the authority a holding rests on:

| Column | Purpose |
|---|---|
| `membership_id` (FK, unique) | The holding |
| `kind` | `elected`, `acclaimed`, `appointed`, `ex_officio` |
| `seat_type`, `seat_id` (polymorphic, null) | A district, a department, a `CommunitySeat` (board seat, representing seat), or none |
| `conferred_by_type`, `conferred_by_id` (polymorphic, null) | A `Candidacy` for an election; an appointment record or board vote otherwise |
| `title` (null) | Free title, e.g. "Minister of Health and Community Services" |
| `end_reason` (null) | `defeated`, `retired`, `resigned`, `died`, `term_ended`, `shuffled`, `dissolved`, `replaced_by_member` |

### Community subtypes and their detail records

Each subtype is an STI class plus an optional detail record (`belongs_to :community`, FK on the detail side).

| Subtype | Detail record | Attributes |
|---|---|---|
| `LegislatureCommunity` | `LegislatureDetail` | `level` (municipal, provincial, territorial, federal, regional), jurisdiction (state or country), seat count, member title ("MHA") |
| `PartyCommunity` | `PartyDetail` | linked `PoliticalParty`, jurisdiction level |
| `ExecutiveCommunity` (cabinet or ministry) | `ExecutiveDetail` | the `LegislativeSession`, `formed_on`, `ended_on`, head role (premier, mayor); parties via associations |
| `DepartmentCommunity` | `DepartmentDetail` | parent department, `predecessor_id` (renames and mergers), mandate text |
| `OrganizationCommunity` (co-op, federation, non-profit) | `OrganizationDetail` (later) | legal form, registry number, incorporated on, governing act |
| `BoardCommunity`, `CommitteeCommunity` | `BoardDetail`, `CommitteeDetail` (later) | size, parent body; term length and electoral system come from governing rules |

Generic role identifiers, so the community says which body: `legislature_member`, `legislature_speaker`,
`legislature_deputy_speaker`, `official_opposition_leader`, `executive_head` (premier), `executive_member` (minister),
`party_member`, `party_leader`, `department_head`, `director`, `chair`, `treasurer`, `organisation_member`.

### Community associations (core design expansion)

CE has no community-to-community relationship today (`PlatformConnection` links platforms, not communities). Both
hierarchy and peer links are needed, and they carry rules about who may join. One record models both:

`CommunityAssociation` (`community_associations`), from `source_community` to `target_community`:

| Column | Purpose |
|---|---|
| `source_community_id`, `target_community_id` (FK) | Direction follows the relation: for a hierarchy, source is the parent |
| `relation` | Identifier from a code registry (below), e.g. `committee_of`, `drawn_from`, `governing_party`, `administers`, `affiliate` |
| `kind` | `hierarchy` (parent to child), `peer`, or `membership` (an organisation belongs to another); derived from the relation, stored for querying |
| `role` (null) | Qualifier such as `lead`, `partner`, `supply_and_confidence`, or a membership class (`full`, `associate`, `affiliate`) |
| `participation` | Who may join the child side: `members_only`, `members_and_invited`, `open`, or `none` (informational link) |
| `eligibility_group` (null) | Associations in one group are alternatives (any of); different groups must all be met |
| `cascade_end` (bool) | Ending the person's membership in the associated community ends their membership here |
| `starts_on`, `ends_on` (null) | Time-box, so a department can move between ministries and a committee can be dissolved |

The relation registry (a Ruby constant, extensible per app, not a table) defines for each relation its kind, whether it
is symmetric, its inverse label, and the default `participation`. Associations are many-to-many: a community may have
several parents and peers, and cycles are rejected by validation. Visibility of an association is the more restrictive
of the two communities' privacy. No permissions are inherited through an association; access is granted only by roles.

Community API (a concern prepended onto `BetterTogether::Community`): `parents`, `children`, `ancestors`,
`descendants` (recursive CTE), `peers`, and `eligibility_for(person)`, which returns `:member`, `:invitation_required`,
`:open` or `:ineligible` from the active associations on a date.

Joining rule, enforced by a validation in the prepended membership concern (it adds to the community's own access mode,
`requires_invitation` and `allow_membership_requests`, and never relaxes it):
- `members_only`: the person needs a current membership in the associated community. Several associations in one
  `eligibility_group` mean "any of"; groups combine as "all of".
- `members_and_invited`: members may join under the community's access mode; anyone else only through an invitation or
  an appointment (a membership whose mandate is `appointed`). This covers committees open to the public or to interest
  groups by appointment.
- `open`: anyone, under the community's access mode; members of the associated community are not privileged.
- `none`: no effect on joining.

How the electoral design uses it:

| Body | Associations | Effect |
|---|---|---|
| Cabinet (executive community) | `drawn_from` the legislature (`members_only`, group `legislature`); `governing_party` to each governing party (`members_only`, group `government`, role `lead` or `partner`, `cascade_end` true) | Only sitting MHAs of the governing party or coalition partners can be ministers; leaving the party ends the cabinet seat. Coalitions are several `governing_party` rows, replacing the separate `GoverningParty` table |
| Cabinet committee (Treasury Board) | `committee_of` the cabinet, `members_only` | Only ministers |
| Cross-party government committee | `committee_of` the legislature, `members_only` | Any MHA, chair appointed from the government side by role |
| Public or stakeholder committee | `committee_of` the legislature, `members_and_invited` | MHAs join; the public and interest groups join by appointment |
| Department | `administers` link from the current cabinet, time-boxed, `none` | History of which ministry ran a department; no joining effect |
| Party caucus | `caucus_of` the party, `members_only` | Party members who are MHAs |
| Coalition partners | `coalition_partner` peer link between parties, symmetric, time-boxed, `none` | Shown on both party pages |

An organisation acting as a member in its own right, with people representing it, is covered in the next section.

### Organisations as members, with representatives (the NLFC case)

The Newfoundland and Labrador Federation of Co-operatives (NLFC) is a membership organisation whose members are co-ops
and associated organisations. A co-op elects a representative to the NLFC board on its behalf, for a bylaw-set term.
Modelled as:

- **Organisation membership** is a `member_of` association (kind `membership`, role `full` or `associate`, time-boxed)
  from the member community to the federation. It is not a Person membership, so it never confers personal permissions.
  Joining still follows the federation's own access mode.
- **Seats** are `CommunitySeat` records (`community_id` = the body, `name`, `kind`, `represents_community_id` null,
  `position`). Kinds: `at_large`, `representing` (held on behalf of a member organisation), `officer`, `ex_officio`. A
  `MembershipMandate.seat` points at one, as it does at a district. The representing seat says whom the holder speaks for.
- **Representatives** are ordinary Person memberships in the federation's board community (role `director`), each with
  a mandate: `kind` `elected`, `seat` = the representing seat, `conferred_by` = the candidacy in the federation's
  election. The system requires the person to hold a current membership in the represented organisation (the same
  eligibility check as `members_only`, applied through the seat).
- **Nomination** by the member organisation is recorded as the candidacy's `nominated_by_community_id`. The electorate of
  the federation election is the member organisations: `Election.electorate` is `persons` or `member_communities`, and
  results are stored per candidacy as for any election.
- **Terms** come from the federation's bylaws (a `term_length` rule, here three years), so the mandate's end defaults to
  start plus the rule. A second consecutive term is a new membership and mandate; display groups them, and a
  `term_limit` rule, if the bylaws set one, is checked when the next mandate is created.
- **Replacing a representative** mid-term ends the mandate (`end_reason: replaced_by_member`) and starts a new one in the
  same seat; the seat and the represented organisation stay constant.

Example: a director sits on the federation board for a co-op. Records: the co-op's `member_of` association to the
federation; a representing seat for that co-op; the person's co-op membership; their board membership with a mandate
(elected, that seat, the AGM candidacy, three-year term); their second term is a second membership and mandate.

The same shape covers ministers representing departments, union delegates on a committee, and party delegates.

### Governing instruments and rules (bylaws and laws)

Every body has rules that decide terms, quorums and who may vote. Two layers, so provenance is kept and the system can
still consult values:

`GoverningInstrument` (`governing_instruments`), the document:

| Column | Purpose |
|---|---|
| `community_id` (FK, null) | The body it governs (a co-op for its bylaws, a legislature for its standing orders); null for statutes with no single body |
| `kind` | `bylaw`, `constitution`, `act`, `regulation`, `policy`, `terms_of_reference` |
| `title`, `citation` | e.g. "Co-operatives Act, SNL 2009 c. C-35.2" (citation to be verified at load) |
| `jurisdiction_type`, `jurisdiction_id` (polymorphic) | The state, country or municipality whose law it is, for acts and regulations |
| `enacted_by_community_id` (FK, null) | The legislature or the body that adopted it |
| `authorized_by_id` (FK to instrument, null) | The higher instrument that gives it force (a bylaw under an Act; a regulation under an Act) |
| `source_url`, `licence`, document attachment | Provenance, in the same style as region data sources |
| `privacy` | Laws are public; a body's bylaws follow its community privacy |

`InstrumentVersion` (`instrument_versions`): `instrument_id`, `version_label`, `adopted_on`, `in_force_from`,
`in_force_to`, `supersedes_id`, text or attachment, `change_summary`. Amendments are new versions, so the rule in force on
a date can always be found, the same approach as `RegionVersion`.

`GoverningRule` (`governing_rules`), a structured value with its clause:

| Column | Purpose |
|---|---|
| `instrument_version_id` (FK) | Where the rule comes from |
| `subject_type`, `subject_id` (polymorphic, null) | A community, a seat, or an election it applies to; null means the whole body |
| `rule_type` | From a registry: `term_length`, `term_limit`, `board_size`, `quorum`, `voting_threshold`, `electorate`, `electoral_system`, `eligibility`, `notice_period`, `fiscal_year_end` |
| `params` (jsonb) | Values, e.g. `{ "years": 3 }` or `{ "consecutive_max": 2 }` |
| `clause` | Citation inside the instrument, e.g. "By-law 4.2" |
| `in_force_from`, `in_force_to` | Window, normally inherited from the version |

Rules are entered by people with a clause citation, never inferred by software. Code asks `GoverningRule.for(subject,
:term_length, on: date)`: a mandate's default end date, an election's default electoral system and electorate, a seat's
eligibility and a committee's participation all read from rules when one exists and fall back to explicit values when not.
Authority forms a chain (Act to bylaw, Act to regulation), shown as "authorized by" on the instrument page, and a bylaw
that conflicts with its authorizing Act is flagged for review, not silently resolved.

Where rules come from: a co-op's bylaws are adopted by its members (an `adopted` vote or resolution is the instrument's
`enacted_by`), municipal bylaws by the council, provincial acts by the House of Assembly, federal acts by Parliament.
Statutes can be ingested later from the official sources with their licences recorded.

### Legislature sessions and governments

- `LegislativeSession` (`belongs_to :community`, the legislature): `number` (51st General Assembly), `election_id` that
  formed it, `starts_on`, `ends_on` (dissolution; election date as default for now).
- `ExecutiveDetail` points at the session. A change of premier mid-session creates a new executive community (a new
  ministry) in the same session; a shuffle does not.
- Governing parties are `governing_party` associations from the executive community to party communities (role `lead`,
  `partner`, `supply_and_confidence`, time-boxed). One association is a single-party government; several are a
  coalition. Majority or minority is computed from seats won by the governing parties against the session's seat
  count. A government with no parties (a municipal council) has none.

### Cabinet roster over time

A minister is a membership in the cabinet community with role `executive_member` and a mandate (`appointed`,
`seat` = the department, `title`). A shuffle ends the old membership (`end_reason: shuffled`) and starts the next on the
same day; someone dropped or added mid-session is just an end or a start. The roster at a date is the memberships current
on that date; a person's portfolio history is their cabinet memberships in order; a department's history is the
mandates whose seat is that department, across ministries. Premier is `executive_head`.

### Constituency offices

`ConstituencyOffice` (`seat_type`/`seat_id`, address, geocoded location, contact details via CE's contactable pattern).
`MandateOffice` joins `mandate_id` to `office_id` with `kind` (`primary`, `satellite`). Consecutive mandates for the same
person and seat share one office; a new office is created when the representative changes. A mandate can have several offices.

### Elections, electoral systems and parties

- `ElectoralSystem` (reference rows): `identifier` (`fptp`, `stv`, `mmp`, `ranked_choice`, `approval`, `plurality_at_large`),
  `winner_rule`, `ballot` (`single`, `ranked`, `multi`), default `seats_per_contest`, `parties_expected` (false for boards).
- `Election` gains `electoral_system_id`, `community_id` (the body elected: legislature, council or board), and `kind`
  (`general`, `by_election`, `municipal`, `board`). Existing NL elections are `general` under `fptp`.
- `ElectoralContest` gains `seats` (default 1; more for at-large, STV or board elections). `Candidacy.party_name` becomes
  nullable; `elected` stays, with an optional `rank` and `round` for ranked and STV results. The model stores rules and
  results, not a tabulation engine.
- Contests with more than one seat produce several elected candidacies, each conferring its own mandate; the seat is the
  body itself or a ward when there is no single district.
- Party on a date is derived from party memberships (party communities, no mandate); the candidacy keeps the party run under.

### Other bodies reuse the same pieces

- Municipal council: `LegislatureCommunity` with `level: municipal`, mayor as `executive_head` in an executive community
  with no governing parties, elections under the municipal electoral system, wards as seats.
- Co-op or non-profit board: `BoardCommunity`, directors elected (kind `elected`, no parties), officers appointed by the
  board (kind `appointed`, `conferred_by` a board vote), election under a plurality or STV system.
- Committees: `CommitteeCommunity` with members appointed by the legislature or board.

### How the NLO data maps

| Data | Model |
|---|---|
| A member's term in a district | A `legislature_member` membership with a mandate (seat = district, candidacy, `elected`) |
| A member's party | A `party_member` membership in the party community |
| Ministers, Speaker, leaders (not yet loaded) | Memberships in the cabinet or legislature with titled mandates |
| `Election`, `ElectoralContest`, `Candidacy` | Kept; gain system, community, kind and seats as above |

## Views and routes

Same shape as other `/e` kinds, plus the new bodies:

- `/e/members/provincial/:province[/:identifier]`: current members, then a member page with current roles, term history
  by community, constituency office, and links to election and district.
- `/e/government/provincial/:province`: the current cabinet roster with portfolios, governing parties, and history by
  ministry; `/e/government/provincial/:province/ministries/:id` for a past one.
- `/e/departments/provincial/:province[/:identifier]`: department, its ministers over time, predecessors.
- Legislature and party community pages list office holders with history.

## Phases (a review gate after each)

1. Foundation, simplified (this is the next build): membership dates and index swap, `MembershipMandate`, quiet
   notifications, the community subtypes (legislature, party, executive, department, committee, organisation) with a
   `LegislatureDetail` only, generic roles, `CommunitySeat`, and community associations (hierarchy, peer and
   membership kinds) with the eligibility rule. Specs, no UI.
2. Governing instruments and rules: instruments, versions, the rule registry and `GoverningRule.for`, wired to mandate
   term lengths. Specs, no UI.
3. Elections reference model: electoral systems, electorate, election community and kind, contest seats, nullable party,
   nominations by organisations, sessions.
4. Constituency offices.
5. Member pages and directory (DOM contracts, screenshots, diagrams).
6. Cabinet and departments: executive communities, governing-party associations, ministers and portfolio history from
   the Assembly pages, government and department views, committees.
7. By-elections, resignations, exact dates, photos and contact details; production rollout with a snapshot before the
   first data-model deploy of this series.

## Risks and checks

- Associations are new core behaviour: keep the eligibility rule additive to CE's access modes, and spec every
  participation mode, the any-of and all-of groups, cycle rejection and `cascade_end`.
- Representation checks (the holder belongs to the represented organisation) and term-limit rules must fail closed with a
  clear message, and be bypassable only by an explicit, logged override.
- Rules are only as good as their entry: every rule needs a clause citation, and rule values are reviewed by a person.
- The index swap changes a CE table from the host app: idempotent, reversible, first backport item.
- Roles and permissions that only make sense for one Community subtype carry that subtype's class name as their
  `resource_type` (for example `NewfoundlandLabradorOnline::PartyCommunity`), so CE's pickers, which match the type
  exactly, never offer them for ordinary communities. Including `BetterTogether::CommunitySubtype` registers each subtype in CE's resource type registry for
  Role and ResourcePermission, `MembershipTimeBox` re-scopes the membership role and rejects a role that does not fit the
  community (generic community roles stay valid everywhere, so `default_member_role` is unchanged). Any new scoped role or
  permission follows the same rule.
- Platform privacy ceiling on each new Community; verify on production.
- Active status and the permission cache must stop counting a holding that ends, without a midnight write.
- Notifications: the flag must cover every notify callback and destroy-time cleanup.
- Seat overlap (one holder per seat per date) and cabinet overlap are app validations, not database constraints.
- Contact details on `ConstituencyOffice` rely on the contactable pattern; confirm it attaches to a non-community record.
- Performance: rosters preload person, role, mandate and seat; keep the query budget spec.

## Backport list (to CE once the design settles)

0. `CommunityAssociation` with the relation registry, the Community API and the eligibility rule (the core expansion).
1. `starts_at`/`ends_at` on memberships, a `TimeBoxed` concern with `current/former/held_on` and non-overlap validation,
   and the unique index including `starts_at`.
2. Active status and permission cache derived from dates.
3. A supported quiet-notification hook for imported memberships.
4. A generic `Mandate` detail record (seat, conferred by, kind, title, end reason).
5. A convention for Community subtypes with detail records and the `default_member_role` lookup.
6. Public membership and office-holder views on Person and Community.
7. Elections generalised to any Community: electoral systems, electorate (persons or member communities), contest
   seats, optional parties, nominations by organisations, sessions.
7a. `CommunitySeat` and organisation membership (`member_of`) with representatives.
7b. `GoverningInstrument`, `InstrumentVersion` and `GoverningRule`, the rule registry and `GoverningRule.for`.
8. Governments and executives (ministries as associations to parties) and departments, if reused beyond NLO.
