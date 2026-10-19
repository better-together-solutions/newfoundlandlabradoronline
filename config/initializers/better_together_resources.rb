# frozen_string_literal: true

ActiveSupport::Reloader.to_prepare do
  require_dependency 'better_together/api/v1/post_resource'
  require_dependency 'better_together/api/v1/page_resource'
  require_dependency 'better_together/api/v1/block_resource'
  require_dependency 'better_together/api/v1/community_resource'
  require_dependency 'better_together/api/v1/event_resource'

  BetterTogether::Api::V1::PostResource.prepend(NewfoundlandLabradorOnline::PostResourceExtension)
  BetterTogether::Api::V1::PageResource.prepend(NewfoundlandLabradorOnline::PageResourceExtension)
  BetterTogether::Api::V1::BlockResource.prepend(NewfoundlandLabradorOnline::BlockResourceExtension)

  NewfoundlandLabradorOnline::LocatableModels.models.each do |model|
    NewfoundlandLabradorOnline::LocatableModels.resource_for(model)
                                               .prepend(NewfoundlandLabradorOnline::LocatableResource)
  end
end
