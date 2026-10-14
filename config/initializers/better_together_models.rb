# frozen_string_literal: true

ActiveSupport::Reloader.to_prepare do
  require_dependency 'better_together/post'

  BetterTogether::Post.include(NewfoundlandLabradorOnline::Post)

  # Video attachments: let CE's rich-text controls accept this app's attachable and
  # let the sanitizer keep its iframe (see NewfoundlandLabradorOnline::ContentSecurityAttachables).
  BetterTogether::ContentSecurity::ActionTextRichTextControls
    .prepend(NewfoundlandLabradorOnline::ContentSecurityAttachables::RichTextControls)
  BetterTogether::ContentSecurity::RichTextAttachmentFilter
    .prepend(NewfoundlandLabradorOnline::ContentSecurityAttachables::AttachmentFilter)
  ActionText::ContentHelper.scrubber = NewfoundlandLabradorOnline::VideoEmbedScrubber.new
end
