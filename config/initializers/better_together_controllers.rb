# frozen_string_literal: true

Rails.application.config.to_prepare do
  # The posts index can be scoped to a settlement (settlement page Posts tab).
  require_dependency 'better_together/posts_controller'
  BetterTogether::PostsController.prepend(NewfoundlandLabradorOnline::SettlementPosts)
  # Likewise the events index (settlement page Events tab).
  require_dependency 'better_together/events_controller'
  BetterTogether::EventsController.prepend(NewfoundlandLabradorOnline::SettlementEvents)

  # Attached video blocks render through CE's CSP-aware iframe_embed_state helper. Action Text
  # renders attachments in whichever controller's view context is current (API responses
  # included), so the helper is added to every view rather than to individual controllers.
  ActionView::Base.include(BetterTogether::Content::BlocksHelper)
  ActionView::Base.include(NewfoundlandLabradorOnline::SettlementMapHelper)
  ActionView::Base.include(NewfoundlandLabradorOnline::ListingMapHelper)
  ActionView::Base.include(BetterTogether::CommunityMarkHelper)
end
