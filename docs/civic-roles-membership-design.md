# Civic roles on CE memberships: design (NLO first)

Status: DRAFT for review, nothing built. Scope: model people's roles in organisations as time-boxed memberships, first for
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
| `seat_type`, `seat_id` (polymorphic, null) | A district, a department, a board seat, or none |
| `conferred_by_type`, `conferred_by_id` (polymorphic, null) | A `Candidacy` for an election; an appointment record or board vote otherwise |
| `title` (null) | Free title, e.g. "Minister of Health and Community Services" |
| `end_reason` (null) | `defeated`, `retired`, `resigned`, `died`, `term_ended`, `shuffled`, `dissolved` |

### Community subtypes and their detail records

Each subtype is an STI class plus an optional detail record (`belongs_to :community`, FK on the detail side).

| Subtype | Detail record | Attributes |
|---|---|---|
| `LegislatureCommunity` | `LegislatureDetail` | `level` (municipal, provincial, territorial, federal, regional), jurisdiction (state or country), seat count, member title ("MHA") |
| `PartyCommunity` | `PartyDetail` | linked `PoliticalParty`, jurisdiction level |
| `ExecutiveCommunity` (cabinet or ministry) | `ExecutiveDetail` | the `LegislativeSession`, `formed_on`, `ended_on`, head role (premier, mayor); parties via associations |
| `DepartmentCommunity` | `DepartmentDetail` | parent department, `predecessor_id` (renames and mergers), mandate text |
| `BoardCommunity`, `CommitteeCommunity` | `BoardDetail`, `CommitteeDetail` (later) | size, term length, electoral system, parent body |

Generic role identifiers, so the community says which body: `legislature_member`, `legislature_speaker`,
`legislature_deputy_speaker`, `official_opposition_leader`, `executive_head` (premier), `executive_member` (minister),
`party_member`, `party_leader`, `department_head`, `director`, `chair`, `treasurer`.

### Community associations (core design expansion)

CE has no community-to-community relationship today (`PlatformConnection` links platforms, not communities). Both
hierarchy and peer links are needed, and they carry rules about who may join. One record models both:

`CommunityAssociation` (`community_associations`), from `source_community` to `target_community`:

| Column | Purpose |
|---|---|
| `source_community_id`, `target_community_id` (FK) | Direction follows the relation: for a hierarchy, source is the parent |
| `relation` | Identifier from a code registry (below), e.g. `committee_of`, `drawn_from`, `governing_party`, `administers`, `affiliate` |
| `kind` | `hierarchy` (parent to child) or `peer`; derived from the relation, stored for querying |
| `role` (null) | Qualifier such as `lead`, `partner`, `supply_and_confidence` |
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

Interest groups participate through their representatives (Persons). A group acting as a member in its own right (an
organisation community joining a committee) is a later extension of the same association.

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

### What becomes of the NLO tables

| Today | After |
|---|---|
| `ElectedTerm` | A `legislature_member` membership with a mandate (seat = district, candidacy, `elected`) |
| `PartyMembership` | A `party_member` membership in the party community |
| Ministers, Speaker, leaders (not yet loaded) | Memberships in the cabinet or legislature with titled mandates |
| `Election`, `ElectoralContest`, `Candidacy` | Kept; gain system, community, kind and seats as above |

Migration is a reversible backfill with row-count and date parity checks; `ElectedTerm` and `PartyMembership` stay until
the new reads are verified in production.

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
   notifications, the community subtypes (legislature, party, executive, department, committee) with a
   `LegislatureDetail` only, generic roles, and community associations with the eligibility rule. Specs, no UI.
2. Elections reference model: electoral systems, election community and kind, contest seats, nullable party, sessions.
3. Backfill `ElectedTerm`/`PartyMembership` into memberships and mandates, with parity report and constituency offices.
4. Member pages and directory (DOM contracts, screenshots, diagrams).
5. Cabinet and departments: executive communities, governing-party associations, ministers and portfolio history from
   the Assembly pages, government and department views, committees.
6. By-elections, resignations, exact dates, photos and contact details; production rollout with a snapshot before the
   first data-model deploy of this series.

## Risks and checks

- Associations are new core behaviour: keep the eligibility rule additive to CE's access modes, and spec every
  participation mode, the any-of and all-of groups, cycle rejection and `cascade_end`.
- A child may not be more public than its parent unless `participation` is `open` (proposed, to confirm).
- The index swap changes a CE table from the host app: idempotent, reversible, first backport item.
- `Joinable#default_member_role` looks up `resource_type: self.class.name`; Community subtypes need roles whose
  `resource_type` matches or an override. Check against the `belongs_to :role` scoping.
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
7. Elections generalised to any Community: electoral systems, contest seats, optional parties, sessions.
8. Governments and executives (ministries as associations to parties) and departments, if reused beyond NLO.
