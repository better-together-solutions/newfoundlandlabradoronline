# frozen_string_literal: true

ActiveSupport::Reloader.to_prepare do
  require_dependency 'better_together/post'
  require_dependency 'better_together/content/video_block'
  require_dependency 'better_together/content/image'

  BetterTogether::Post.include(NewfoundlandLabradorOnline::Post)
  BetterTogether::Content::VideoBlock.include(NewfoundlandLabradorOnline::VideoBlock)
  BetterTogether::Content::Image.include(NewfoundlandLabradorOnline::ImageBlock)

  # Video attachments: let CE's rich-text controls accept the video block as an attachable and
  # let the sanitizer keep its iframe (see NewfoundlandLabradorOnline::ContentSecurityAttachables).
  BetterTogether::ContentSecurity::ActionTextRichTextControls
    .prepend(NewfoundlandLabradorOnline::ContentSecurityAttachables::RichTextControls)
  BetterTogether::ContentSecurity::RichTextAttachmentFilter
    .prepend(NewfoundlandLabradorOnline::ContentSecurityAttachables::AttachmentFilter)
  ActionText::ContentHelper.scrubber = NewfoundlandLabradorOnline::VideoBlockScrubber.new
end
