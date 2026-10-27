# CE backport assessment (2026-10-26)

Compared every host override under `app/`, `config/initializers/` and `lib/` against Community Engine (CE) `8fba847c5` (0.11.0 plus the merged events, series, API and community tabs work, PRs #1986 to #1995, #1999, #2001). This PR bumps the pin; the overrides below are not yet deleted.

## Migrations

CE has no engine migration newer than the old pin except the two event series ones. NLO's host copies (`20261024100000_add_series_to_better_together_events.rb`, `20261024100100_create_better_together_event_series_sessions.rb`) are byte-identical to the engine's, and both are guarded (`column_exists?`, `index_name_exists?`, `table_exists?`). `better_together:install:migrations` skips them as same-name duplicates, copies nothing, and `db/schema.rb` does not change. If the host copies are ever deleted in favour of the engine's, the engine copies get new versions on install and run as no-ops on production; the old versions then show as `NO FILE`, which is harmless. Recommendation: keep the host copies until the pin is deployed, then decide.

CE's phase 10 to 13 `platform_id` migrations are not in NLO by name, but the schema already has `platform_id` on those tables and the migrations guard with `column_exists?`, so they cannot conflict. The engine's migrations are not appended to the host paths because the host has `*.better_together.rb` files.

## A. Backported to CE: host copy deleted (status after the follow-up PR)

Deleted: the event series concerns, partials, controller concern and locale keys (specs and screenshots now follow CE's disposition names); the event and community API extensions and the `ContactData`, `EventHosting`, `CommunityImages`, `EventImages`, `EventBlockAttachments` concerns; `CommunityScope`, `CommunityEvents`; the copies of `events/show`, `_event`, `_event_host_fields`, `_host`, `communities/_community`, `shared/_community_chip`; `CommunityMarkHelper` (byte-identical to CE's); `LocationDisplayName` and `LocatedMapPoints`.

Kept, rebased onto CE `8fba847c5` with only the NLO additions:
- `events/index`, `events/_list_form`, `posts/index`, `posts/_list_form`: the settlement scope (hidden field, heading). Frames now come from CE's `index_frame_id` (the Turbo-Frame request header), so request specs send that header.
- `communities/show`: logo in the header, the settlement link in the located-in line, the live image card.
- `LocatableResource` (`settlement_identifier`; adds `address_data` only to resources that lack it) and `LocationInterface` (settlement location and Post `address_data`).

Behaviour changes accepted by adopting CE: on an event page and card the series line now follows the location (it preceded it in NLO), and the cancel or delete panel uses `series_action`/`disposition` ids.

## B. Generic, not in CE yet (candidate backports)

| NLO file | What it does | Size | Priority |
|---|---|---|---|
| `PrivatePrimaryCommunity` | primary community of a person or region stays private | 20 lines | high, small |
| `MentionPrefetch` + `MentionVisibility` | one query for which mentioned people the viewer can see; removes per-person policy checks on lists | about 25 lines | high, perf |
| `DefaultCoverImage` | restores a generated default cover when the cover is cleared | 41 | medium |
| `PostCoverImage`, `PostVideo`, `ImageBlock`, `VideoBlock`, `VideoBlockScrubber` | post cover via base64, featured video block, image/video blocks as Action Text attachments | about 190 | medium (CE has `VideoBlock` and `Image` media_data; check what remains) |
| `LocationPickerHelper` + `locations/picker` partial, `LocationQueries`, `LocatableModels` | shared location picker and "located in a place" queries | about 150 | medium, needs views, screenshots and diagrams |
| `ListingMap`, `ListingMapHelper`, `shared/listing_map` | map above index lists (regions, settlements) | about 190 | lower |
| `BotPersonCleanupService` | guarded cleanup of bot person records | 251 | removed: CE's `better_together:people:hard_delete` (`PersonHardDeletionExecutor`) already breaks the creator/protected cycle and removes the primary community, calendars and memberships |
| `CommunitySubtype`, `SubtypeResourceTypes`, `RoleResourceTypeLabels` | roles scoped to a Community subtype (STI) | about 75 | medium; a CE extension point for host subtypes |
| `ExpireMemberPermissionCacheJob` | permission cache expiry on time-boxed memberships | small | tied to civic roles design |
| Host hook views (`_extra_form_content`, `_extra_form_tabs`, `people/_extra_person_tab_contents`, `host_dashboard/_host_app_resources`) | CE's own empty extension points | none | n/a, intended overrides |

## C. Stays in NLO

Provinces, regions and electoral districts (`Region`/`State` concerns, `Province`, `District*`), elections, parties, legislatures, candidacies, seats, terms, community associations and committees, civic role migrations, settlement pages (`SettlementEvents`, `SettlementPosts`, `SettlementMap`, `geography/settlements/*`), CBO live images, `newfoundland_labrador_online.*` locales, theme and CSP initializers, layout hooks (`_custom_head_javascript`, `_custom_stylesheets`), Stimulus controllers for live images and party overlay.

## Suggested next steps

1. CE PRs, in order: `PrivatePrimaryCommunity`; `MentionPrefetch`/`MentionVisibility`; a hook for extra scope params in framed indexes (removes the four settlement view copies); `DefaultCoverImage`; community subtype extension point; location picker.
