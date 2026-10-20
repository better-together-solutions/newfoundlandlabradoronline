# Civic roles: usage guide (phase 1 foundation)

Design: `docs/civic-roles-membership-design.md`. Schema: `docs/diagrams/exports/png/nlo_civic_roles_schema_erd.png`.
Everything lives in NLO (concerns wired in `config/initializers/better_together_models.rb`); the backport list is in the design doc.

## Time-boxed memberships

`BetterTogether::PersonCommunityMembership` has optional `starts_at` and `ends_at`. No dates means open ended, as before.

```ruby
membership = BetterTogether::PersonCommunityMembership.create!(
  member: person, joinable: community, role:, status: 'active',
  starts_at: BetterTogether::PersonCommunityMembership.local_midnight(Date.new(2025, 10, 14)),
  ends_at: BetterTogether::PersonCommunityMembership.local_midnight(Date.new(2029, 10, 14))
)
```

- Scopes: `held_on(time)`, `current`, `former`, `upcoming`, `overlapping(from, to)`. `.active` means status active and current.
- The same role can recur in successive terms; overlapping holdings of one role are rejected.
- Dates are calendar dates at local midnight in `America/St_Johns` (`local_midnight`).
- A job expires the member's permission cache when a future window starts or ends.
- Imports: set `skip_notifications = true` to stay quiet and `skip_eligibility = true` to bypass association checks.
- Ending a membership ends dependent memberships in communities linked by an association with `cascade_end`.

## Mandates and seats

`MembershipMandate` (one per membership) records what the membership rests on: `kind` (elected, acclaimed, appointed,
ex_officio), the `seat` (a district region or a `CommunitySeat`), `conferred_by` (a candidacy), `title` and `end_reason`.
`CommunitySeat` kinds: `at_large`, `representing` (needs `represents_community`; the holder must be a current member of it),
`officer`, `ex_officio`.

## Community subtypes and roles

STI on `type`: `LegislatureCommunity` (with `legislature_detail`), `PartyCommunity`, `ExecutiveCommunity`,
`DepartmentCommunity`, `CommitteeCommunity`, `OrganizationCommunity`. They route, authorise and use roles as plain
Communities. Seed the generic office roles (no permissions, idempotent) with `bin/rails nlo:civic:seed_roles`.

## Community associations

`CommunityAssociation` links a source community to a target; the participation mode governs joining the target.

| Participation | Who may join the target |
|---|---|
| `members_only` | Current members of the source (same `eligibility_group` = any of; different groups = all of) |
| `members_and_invited` | Source members, or anyone invited or appointed |
| `open` | Anyone, under the community's own access mode |
| `none` | Informational link |

Relations come from `CommunityAssociationRegistry` (`committee_of`, `drawn_from`, `administers`, `caucus_of`,
`governing_party`, `coalition_partner`, `member_of`, `affiliate`), which sets kind and default participation. Hierarchy
cycles are rejected, and a child may not be more public than its parent unless participation is `open`.

Community API: `parents`, `children`, `peers`, `ancestors`, `descendants` (recursive query), `eligibility_for(person, on:,
invited:)` returning `:member`, `:invited`, `:invitation_required`, `:open` or `:ineligible`. Creating a membership
applies this check on top of the community's own access mode.

## Not yet built

Governing instruments and rules, election reference model, backfill of elected terms, member pages, cabinet and
committee data (design doc phases 2 to 7).
