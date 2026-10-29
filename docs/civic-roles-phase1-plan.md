# Civic roles, phase 1 build plan: foundation

Status: BUILT (phase 1 foundation), see docs/civic-roles.md. Parent design: `docs/civic-roles-membership-design.md`. Goal: re-orient the model so
memberships are time-boxed, communities have subtypes and associations, and mandates and seats exist. No UI, no data
loaded, no production deploy.

## Scope

In: membership dates and the unique index swap; `MembershipMandate`; `CommunitySeat`; community subtypes (legislature,
party, executive, department, committee, organisation) with `LegislatureDetail` only; generic roles; community
associations (hierarchy, peer, membership) with the eligibility rule and the child-privacy rule; quiet notifications.

Out (later phases): governing instruments and rules, electoral systems and sessions, member pages, cabinet and committees data, constituency offices, by-elections.

## Facts checked in the CE gem (pin 929bb51a9492)

- `person_community_memberships` has no `type`, dates or detail columns; its unique index is
  (`joinable_id`, `member_id`, `role_id`). Roles are seeded by `AccessControlBuilder` with
  `resource_type: 'BetterTogether::Community'`.
- The permission cache joins only roles that have permissions, so roles without permissions are inert. Cached for 12 hours.
- `Member#active_membership_relation_for` calls the membership class's `.active` scope when present.
- `Joinable#default_member_role` looks up `resource_type: self.class.name`, which would miss for a Community subtype.
- `Community` has a `type` column (STI-ready) and `PrivacyCeilingValidatable` limits privacy by platform and community.
- Notification callbacks on `PersonCommunityMembership` are private methods on the model, so a prepended module can
  override them.

## Work breakdown

### 1. Migrations (idempotent: `table_exists?`, `column_exists?`, `index_exists?`; reversible)

1. `AddTimeBoxToCommunityMemberships`: `starts_at`, `ends_at` (datetime, null) on `better_together_person_community_memberships`;
   check constraint `ends_at > starts_at`; replace the unique index with (`joinable_id`, `member_id`, `role_id`,
   `starts_at`) nulls not distinct; index (`joinable_id`, `starts_at`, `ends_at`). `down` restores the old index and
   raises a clear error if duplicates would violate it.
2. `CreateMembershipMandatesAndCommunitySeats`: `community_seats` (`community_id`, `name`, `kind`,
   `represents_community_id` null, `position`; unique (`community_id`, `name`)); `membership_mandates` (`membership_id`
   unique FK, `kind`, `seat_type`/`seat_id`, `conferred_by_type`/`conferred_by_id`, `title`, `end_reason`).
3. `CreateCommunityAssociations`: `source_community_id`, `target_community_id`, `relation`, `kind`, `role`,
   `participation`, `eligibility_group`, `cascade_end`, `starts_on`, `ends_on`; unique (`source_community_id`,
   `target_community_id`, `relation`, `starts_on`) nulls not distinct; check `source <> target`; index on each side.
4. `CreateLegislatureDetails`: `community_id` unique FK, `level`, `jurisdiction_type`/`jurisdiction_id`, `seat_count`,
   `member_title`.

No migration for the subtypes: they use the existing `communities.type` column.

### 2. Models and concerns (all in NLO, wired in `config/initializers/better_together_models.rb`)

- `NewfoundlandLabradorOnline::MembershipTimeBox`, prepended on `PersonCommunityMembership`: scopes `held_on(date)`,
  `current`, `former`; `.active` also requires a current holding; validation rejecting overlapping holdings of one role
  for a person and community; a job scheduled at `ends_at` that expires the member's permission cache;
  `skip_notifications` flag that no-ops the four notify callbacks and the destroy cleanup.
- `MembershipMandate` and `CommunitySeat` (`kind`: `at_large`, `representing`, `officer`, `ex_officio`; a representing
  seat requires `represents_community`). The prepended concern gives the membership `has_one :mandate`.
- `CommunityAssociation` with a code registry `CommunityAssociationRegistry` defining each relation (kind, symmetric,
  inverse label, default participation, allowed roles). Initial relations: `committee_of`, `caucus_of`, `drawn_from`,
  `governing_party`, `administers`, `coalition_partner`, `member_of`, `affiliate`. Validations: relation known, no
  self-link, no hierarchy cycle (recursive CTE), the child may not be more public than the parent unless
  `participation` is `open`.
- `NewfoundlandLabradorOnline::Associable`, included in `BetterTogether::Community`: associations, `parents`,
  `children`, `ancestors`, `descendants`, `peers`, `eligibility_for(person, on:)`.
- Membership eligibility validation (in the prepended concern): on create, apply `members_only` (all groups must be
  met, any-of within a group), `members_and_invited` (members, or an invitation, or an `appointed` mandate) and
  `open`, in addition to the community's own access mode. A representing seat requires a current membership in the
  represented organisation. A logged `skip_eligibility` flag exists for imports only.
- `cascade_end`: ending a membership in the associated community ends the person's dependent memberships on the same date.
- Subtypes `LegislatureCommunity`, `PartyCommunity`, `ExecutiveCommunity`, `DepartmentCommunity`, `CommitteeCommunity`,
  `OrganizationCommunity` < `BetterTogether::Community`, each overriding `default_member_role` to use the
  `BetterTogether::Community` role scope, plus `policy_class` and `model_name` delegating to `Community` so policies,
  routes and forms keep working. `LegislatureDetail` and `has_one :legislature_detail` on `LegislatureCommunity`.

### 3. Roles

`NewfoundlandLabradorOnline::Civic::RoleSeeder` (idempotent, rake task `nlo:civic:seed_roles`): `legislature_member`,
`legislature_speaker`, `legislature_deputy_speaker`, `official_opposition_leader`, `executive_head`,
`executive_member`, `party_member`, `party_leader`, `department_head`, `director`, `chair`, `treasurer`,
`organisation_member`. Resource type `BetterTogether::Community`, no permissions, names hand-written in en, es and fr.

### 4. Specs (hermetic; targeted first, then the full suite)

- Migrations: up, down and re-run are idempotent; index swap; duplicate guard on down.
- Time-boxing: scopes, overlap validation, `.active` semantics, same role in successive holdings, cache expiry job.
- Quiet notifications: no notifier or mailer enqueued when the flag is set; normal memberships still notify.
- Mandates and seats: validations, a representing seat requires the represented organisation membership.
- Associations: registry, cycles, privacy rule, every participation mode, any-of and all-of groups, `cascade_end`,
  time-boxed associations, `eligibility_for`; the cabinet, public committee and NLFC examples from the design as
  scenario specs.
- Subtypes: STI load, policy and route lookups, `default_member_role`.
- A regression spec that ordinary (null-dated) CE memberships behave exactly as before.

### 5. Documentation

Update the design doc status, add a generated ERD (`nlo_civic_roles_schema_erd`) via `scripts/export_diagrams.rb`, and a
short `docs/civic-roles.md` usage guide. No views change, so no screenshots are needed.

## Order and checkpoints

1. Migrations 1 and 2, time-box concern, mandate and seat, specs. Commit.
2. Subtypes, roles, quiet notifications, specs. Commit.
3. Associations, registry, eligibility and privacy rules, scenario specs. Commit.
4. Docs and diagrams, full suite, rubocop, i18n-tasks, `db:migrate:redo`. Commit and push.

## Risks

- STI subtypes of a CE class: Pundit and route helpers resolve by class name, so `policy_class` and `model_name` overrides
  are required and covered by specs.
- The unique index swap touches a CE table: small table, idempotent, reversible, first backport item.
- Overriding `.active` on a CE class: confirm no CE query relies on status alone for permission-bearing roles.
- Eligibility checks must fail closed with a clear error; the import bypass is explicit and logged.

## Decisions for you

1. Branch: a new branch stacked on PR #213's head (`feat/civic-roles-foundation`) with its own PR, or continue on the same
   branch. I recommend the stacked branch, since this is a different concern from regions and elections.
2. Production: phase 1 changes a CE table and adds nothing visible. I recommend not deploying until the data phase,
   with a snapshot taken before that first data-model deploy.
3. Role identifiers are generic and unprotected, with no permissions. Confirm you want them seeded through a rake task
   and a deploy step rather than a migration.
