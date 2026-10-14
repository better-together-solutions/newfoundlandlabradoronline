# frozen_string_literal: true

ActiveSupport::Reloader.to_prepare do
  require_dependency 'better_together/api/v1/post_resource'

  BetterTogether::Api::V1::PostResource.prepend(NewfoundlandLabradorOnline::PostResourceExtension)
end
