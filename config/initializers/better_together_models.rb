# frozen_string_literal: true

ActiveSupport::Reloader.to_prepare do
  require_dependency 'better_together/post'
  require_dependency 'better_together/content/video_block'
  require_dependency 'better_together/content/image'
  require_dependency 'better_together/community'
  require_dependency 'better_together/event'
  require_dependency 'better_together/geography/region'

  BetterTogether::Post.include(NewfoundlandLabradorOnline::Post)
  # Regions: versioned boundaries and external identifiers (the typed subclasses live in app/models).
  BetterTogether::Geography::Region.include(NewfoundlandLabradorOnline::Region)
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
