# frozen_string_literal: true

ActiveSupport::Reloader.to_prepare do
  require_dependency 'better_together/api/v1/post_resource'
  require_dependency 'better_together/api/v1/community_resource'
  require_dependency 'better_together/api/v1/event_resource'

  BetterTogether::Api::V1::PostResource.prepend(NewfoundlandLabradorOnline::PostResourceExtension)
  BetterTogether::Api::V1::CommunityResource.prepend(NewfoundlandLabradorOnline::CommunityResourceExtension)
  BetterTogether::Api::V1::EventResource.prepend(NewfoundlandLabradorOnline::EventResourceExtension)

  NewfoundlandLabradorOnline::LocatableModels.models.each do |model|
    NewfoundlandLabradorOnline::LocatableModels.resource_for(model)
                                               .prepend(NewfoundlandLabradorOnline::LocatableResource)
  end
end
