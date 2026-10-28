# Locatable records: how locations work and how to onboard a model

Status: implemented in the `feat/cbo-locations` branch. Host-app concerns; the CE backport notes are at the end.

## What a location is

A record is located by one `BetterTogether::Geography::LocatableLocation` row (table exists in CE, no migration here). The row points at a place (`location`, polymorphic: Settlement, Region, Address, Building) or carries only a free-text `name`. One row per record.

Two layers decide where a record "is":

1. **Explicit**: the record's own location row. It always wins.
2. **Derived**: a record with no location row of any kind takes the location of the record named by `inherit_location_from` (a post takes its community's). A record whose row holds only free text counts as explicitly located and inherits nothing.

`Model.located_in(place)` returns each record once, whichever way it qualifies:

- its own location is the place, or
- its own location is an address or building that CE has placed within the place (`HierarchyResolutionJob` stores that as a `LocatableLocation` of the address pointing at the settlement), or
- it has no location row and its inherited record (for example its community) qualifies by either rule above.

## The three interfaces every locatable record has

| Interface | How |
|---|---|
| Forms | the shared picker partial CE's `better_together/locations/_picker` (settlement, region, address, building, free text, inline new address) |
| API | writable and readable attribute `settlement_identifier` on the model's JSON:API resource (blank or null clears; an unknown identifier is a validation error and nothing is created) |
| Console and code | `record.settlement_identifier = 'corner-brook'`, `record.location`, `record.effective_location`, `Model.located_in(place)` |

The nested `location_attributes` (what the picker posts) is permitted through the model's `extra_permitted_attributes`.

## Onboarding a model (4 steps)

1. Add the model to `ONBOARDED` in `app/models/concerns/newfoundland_labrador_online/locatable_models.rb`. Use `{ concern: :locatable }` for a model with no location yet (it gets the `has_one :location`, nested attributes and the interface), or `{ concern: :interface }` when CE already gives it `Geography::Locatable::One` (events: interface only). Add `inherit: :association` to take a parent's location when it has none.
2. Run the shared examples against it: in `spec/models/concerns/newfoundland_labrador_online/locatable_spec.rb` add a `describe` that defines `record` (a saved record without a location) and `it_behaves_like 'a locatable record'` (`spec/support/locatable_record_examples.rb`). The registry, resource and interface are then covered automatically (the resource spec iterates the registry).
3. Put the picker in the model's form: `<%= render 'better_together/locations/picker', form: form, record: record %>`. If the form has no hook, make a host copy of the CE form with a version header (posts do this) or use the existing `_extra_form_*` partial hooks (communities do this).
4. Nothing else for the API: `wire!` prepends `LocatableResource` onto the model's resource through `config/initializers/better_together_resources.rb`.

Pending, not yet onboarded (listed in `PENDING`, covered by a registry spec so they are not forgotten): `BetterTogether::Joatu::Offer` and `BetterTogether::Joatu::Request`.

## Files

- `app/models/concerns/newfoundland_labrador_online/{locatable,location_interface,locatable_models}.rb`
- `app/resources/newfoundland_labrador_online/locatable_resource.rb`
- The picker partial, helper, `/:locale/locations/available` lookup, `LocationQueries` and the `located_in` scope with `inherit_location_from` are CE's (`BetterTogether::Geography::Locatable::LocatedIn`, `docs/development/location_picker.md` in CE)
- `app/controllers/concerns/newfoundland_labrador_online/settlement_posts.rb` (posts index `?settlement=`)
- Views copied from CE with version headers: `posts/_form`, `posts/index`, `posts/_list_form`, `geography/settlements/show`; the community page and form use CE hook partials (`_header_media`, `_location_line`, `_about_extra`, `_extra_form_tabs`, `_extra_form_content`).

## Settlement page

- Map: pin, boundary and located items with coordinates, see `docs/settlement-map.md`. New onboarded models need a `map:` colour and icon in `LocatableModels`.

- Posts tab: lazy turbo frame loading `/posts?settlement=<identifier>`, the normal posts index (filter sidebar, view switcher, pagination) scoped by `Post.located_in(settlement)` through `policy_scope`. Location never widens visibility.
- Communities tab: cards for the communities located in the settlement (policy scoped); the community page shows "Located in <settlement>".

## Performance note

`located_in` is built from `IN (subquery)` on `locatable_locations`. Its indexes lead with the locatable, so a query that starts from the place scans the table. Fine at thousands of rows; CE should add an index on `(location_type, location_id, locatable_type)` when this moves into the gem.

## CE backport notes

- Reassess `Locatable::One` including `Mappable` (one `Map` row per located record). Locatable items should be includable on a map as map items without each owning a map record; the host concern deliberately uses a plain `has_one` until that design is settled.
- `settlement_identifier` is still host-side. Replace the commented posts pane of the settlement page; let `posts/index` take an embedded and filter-path mode.
- Index migration above.
