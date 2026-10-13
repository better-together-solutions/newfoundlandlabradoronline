# frozen_string_literal: true

ActiveSupport::Reloader.to_prepare do
  require_dependency 'better_together/post'

  BetterTogether::Post.include(NewfoundlandLabradorOnline::Post)
end
