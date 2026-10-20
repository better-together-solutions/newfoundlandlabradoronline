# frozen_string_literal: true

ActiveSupport::Reloader.to_prepare do
  require_dependency 'better_together/post'
  require_dependency 'better_together/content/video_block'
  require_dependency 'better_together/content/image'
  require_dependency 'better_together/community'
  require_dependency 'better_together/event'
  require_dependency 'better_together/geography/region'
  require_dependency 'better_together/geography/state'
  require_dependency 'better_together/geography/state_policy'
  require_dependency 'better_together/person'
  require_dependency 'better_together/person_community_membership'

  BetterTogether::Post.include(NewfoundlandLabradorOnline::Post)
  # Regions: versioned boundaries and external identifiers (the typed subclasses live in app/models).
  BetterTogether::Geography::Region.include(NewfoundlandLabradorOnline::Region)
  # Provinces: the districts, parties and elections scoped to them.
  BetterTogether::Geography::State.include(NewfoundlandLabradorOnline::State)
  BetterTogether::Geography::StatePolicy.prepend(NewfoundlandLabradorOnline::StatePolicy)
  # Elected members: a person's terms in district seats.
  BetterTogether::Person.include(NewfoundlandLabradorOnline::Person)
  # Civic roles (docs/civic-roles-membership-design.md): time-boxed memberships and community associations.
  BetterTogether::PersonCommunityMembership.prepend(NewfoundlandLabradorOnline::MembershipTimeBox)
  BetterTogether::Community.include(NewfoundlandLabradorOnline::Associable)
  BetterTogether::CommunityPolicy::Scope.prepend(NewfoundlandLabradorOnline::CommunityPolicyScope)
  # Locations: every record in LocatableModels gets the shared location interface.
  NewfoundlandLabradorOnline::LocatableModels.wire!
  BetterTogether::Content::VideoBlock.include(NewfoundlandLabradorOnline::VideoBlock)
  BetterTogether::Content::Image.include(NewfoundlandLabradorOnline::ImageBlock)

  # Video and image blocks are accepted in rich text and rendered while public (CE's attachable registry); the
  # scrubber keeps the video iframe (see NewfoundlandLabradorOnline::VideoBlockScrubber).
  BetterTogether::ContentSecurity::AttachableRegistry.register(
    'BetterTogether::Content::VideoBlock', 'BetterTogether::Content::Image'
  )
  ActionText::ContentHelper.scrubber = NewfoundlandLabradorOnline::VideoBlockScrubber.new
end

# Roles and permissions may be scoped to one Community subtype instead of every community.
ActiveSupport::Reloader.to_prepare do
  NewfoundlandLabradorOnline::SubtypeResourceTypes.wire!
end
