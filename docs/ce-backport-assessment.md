# CE backport assessment (2026-10-26)

Compared every host override under `app/`, `config/initializers/` and `lib/` against Community Engine (CE) `8fba847c5` (0.11.0 plus the merged events, series, API and community tabs work, PRs #1986 to #1995, #1999, #2001). This PR bumps the pin; the overrides below are not yet deleted.

## Migrations

CE has no engine migration newer than the old pin except the two event series ones. NLO's host copies (`20261024100000_add_series_to_better_together_events.rb`, `20261024100100_create_better_together_event_series_sessions.rb`) are byte-identical to the engine's, and both are guarded (`column_exists?`, `index_name_exists?`, `table_exists?`). `better_together:install:migrations` skips them as same-name duplicates, copies nothing, and `db/schema.rb` does not change. If the host copies are ever deleted in favour of the engine's, the engine copies get new versions on install and run as no-ops on production; the old versions then show as `NO FILE`, which is harmless. Recommendation: keep the host copies until the pin is deployed, then decide.

CE's phase 10 to 13 `platform_id` migrations are not in NLO by name, but the schema already has `platform_id` on those tables and the migrations guard with `column_exists?`, so they cannot conflict. The engine's migrations are not appended to the host paths because the host has `*.better_together.rb` files.

## A. Backported to CE: host copy can be deleted (needs a follow-up PR)

| NLO file | CE counterpart | Difference to resolve |
|---|---|---|
| `app/views/better_together/events/show.html.erb` | same path | NLO copy is at `1b1c9fc9e62a`; CE moved the series banner and other dates, added `id="event-tabbed-section"` and `map_label` without default |
| `events/_event.html.erb` | same path, `EventsHelper#event_card_cache_key` | cache key now in a helper, mention placement |
| `events/index.html.erb`, `events/_list_form.html.erb`, `posts/index.html.erb`, `posts/_list_form.html.erb` | same paths with `index_frame_id` (`FramedIndex`) | NLO derives frames from `@settlement`/`@scoped_community`; CE from the Turbo-Frame request id. NLO's settlement frames (`settlement-events`, `settlement-posts`) need the CE frame id to match, or a small NLO hook |
| `events/_host.html.erb`, `_event_host_fields.html.erb`, `shared/_community_chip.html.erb`, `communities/_community.html.erb` | same paths plus `BetterTogether::CommunityMarkHelper` | NLO has its own `NewfoundlandLabradorOnline::CommunityMarkHelper`; drop it once CE's gives the same output |
| `communities/show.html.erb` | same path (tabs controller, contact tab, map) | NLO copy is at `929bb51a9492`. Keep only the NLO-specific live image card and located-in line, via a hook or a thin override |
| `app/models/concerns/better_together/event_series.rb`, `event_series_listing.rb`, `event_series_map.rb`, `event_series_settlement.rb`, `event_series_session.rb` (identical), `events/_series_*.html.erb` | `EventSeries`, `EventSeriesDisposition`, `series_disposition` partial | CE renamed settlement to disposition (`series_action`, `events.series.disposed`); NLO still uses `settle`/`settled`. NLO's `ListScopes` prepend (series excluded from `upcoming`/`past`) is not in CE, so the delete needs either that in CE or kept in NLO |
| `controllers/concerns/better_together/event_series_actions.rb` | same path | same rename; CE includes it, NLO prepends it |
| `NewfoundlandLabradorOnline::ContactData`, `EventHosting` | `BetterTogether::ContactData`, `EventHosting` | CE has both; NLO still includes its own (the `[DUPLICATE ATTRIBUTE]` boot warnings for `series`, `session_of`, `series_identifier` and `address_data` come from NLO's resource extensions redefining CE's) |
| `CommunityImages`, `EventImages`, `EventBlockAttachments`, `LocationInterface`, `LocatableResource#address_data` half | `Community`/`Event` `logo_data`, `cover_image_data`, `BlockAttachments`, `Locatable::AddressData` | CE implements them under other names; remove NLO's after the series and settlement rename |
| `LocationDisplayName`, `LocatedMapPoints` | `LocatableLocation` display, `Locatable::LocationMapPoints` | confirm parity by spec before deleting |

Acceptance for each delete: NLO's request, DOM-contract and docs-screenshot specs pass unchanged (462 examples today) and the generated screenshots match.

## B. Generic, not in CE yet (candidate backports)

| NLO file | What it does | Size | Priority |
|---|---|---|---|
| `PrivatePrimaryCommunity` | primary community of a person or region stays private | 20 lines | high, small |
| `MentionPrefetch` + `MentionVisibility` | one query for which mentioned people the viewer can see; removes per-person policy checks on lists | about 25 lines | high, perf |
| `DefaultCoverImage` | restores a generated default cover when the cover is cleared | 41 | medium |
| `PostCoverImage`, `PostVideo`, `ImageBlock`, `VideoBlock`, `VideoBlockScrubber` | post cover via base64, featured video block, image/video blocks as Action Text attachments | about 190 | medium (CE has `VideoBlock` and `Image` media_data; check what remains) |
| `LocationPickerHelper` + `locations/picker` partial, `LocationQueries`, `LocatableModels` | shared location picker and "located in a place" queries | about 150 | medium, needs views, screenshots and diagrams |
| `ListingMap`, `ListingMapHelper`, `shared/listing_map` | map above index lists (regions, settlements) | about 190 | lower |
| `BotPersonCleanupService` | guarded cleanup of bot person records | 251 | lower, ops tooling; may belong in management-tool |
| `CommunitySubtype`, `SubtypeResourceTypes`, `RoleResourceTypeLabels` | roles scoped to a Community subtype (STI) | about 75 | medium; a CE extension point for host subtypes |
| `ExpireMemberPermissionCacheJob` | permission cache expiry on time-boxed memberships | small | tied to civic roles design |
| Host hook views (`_extra_form_content`, `_extra_form_tabs`, `people/_extra_person_tab_contents`, `host_dashboard/_host_app_resources`) | CE's own empty extension points | none | n/a, intended overrides |

## C. Stays in NLO

Provinces, regions and electoral districts (`Region`/`State` concerns, `Province`, `District*`), elections, parties, legislatures, candidacies, seats, terms, community associations and committees, civic role migrations, settlement pages (`SettlementEvents`, `SettlementPosts`, `SettlementMap`, `geography/settlements/*`), CBO live images, `newfoundland_labrador_online.*` locales, theme and CSP initializers, layout hooks (`_custom_head_javascript`, `_custom_stylesheets`), Stimulus controllers for live images and party overlay.

## Suggested next steps

1. NLO follow-up PR: delete group A overrides one cluster at a time (series rename and `ListScopes` first, then frames and views, then the API extensions), each gated on the existing specs.
2. CE PRs, in order: `PrivatePrimaryCommunity`; `MentionPrefetch`/`MentionVisibility`; a series list-scope hook so `upcoming`/`past` exclude series; `DefaultCoverImage`; community subtype extension point; location picker.
