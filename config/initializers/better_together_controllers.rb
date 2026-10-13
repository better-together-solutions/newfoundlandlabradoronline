# frozen_string_literal: true

Rails.application.config.to_prepare do
  require_dependency 'better_together/posts_controller'

  # Post views render videos through CE's CSP-aware iframe_embed_state helper.
  BetterTogether::PostsController.helper(BetterTogether::Content::BlocksHelper)
end
