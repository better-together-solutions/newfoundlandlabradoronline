# frozen_string_literal: true

Rails.application.config.to_prepare do
  # The posts index can be scoped to a settlement (settlement page Posts tab).
  require_dependency 'better_together/posts_controller'
  BetterTogether::PostsController.prepend(NewfoundlandLabradorOnline::SettlementPosts)

  # API writes run in a fixed locale (see ApiLocale); the web controllers leak theirs onto the thread.
  require_dependency 'better_together/api/application_controller'
  BetterTogether::Api::ApplicationController.include(NewfoundlandLabradorOnline::ApiLocale)

  # Attached video blocks render through CE's CSP-aware iframe_embed_state helper. Action Text
  # renders attachments in whichever controller's view context is current (API responses
  # included), so the helper is added to every view rather than to individual controllers.
  ActionView::Base.include(BetterTogether::Content::BlocksHelper)
  ActionView::Base.include(NewfoundlandLabradorOnline::LocationPickerHelper)
  ActionView::Base.include(NewfoundlandLabradorOnline::SettlementMapHelper)
end
