# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Rich-text scrubber that keeps CE's allowed tags and attributes and additionally lets
  # through the privacy-enhanced YouTube iframe rendered inside a video attachment.
  # Any other iframe is still removed.
  class VideoBlockScrubber < Rails::HTML::PermitScrubber
    EXTRA_ATTRIBUTES = %w[allow allowfullscreen frameborder referrerpolicy].freeze

    def initialize
      super
      self.tags = base_tags + [ActionText::Attachment.tag_name, 'figure', 'figcaption', 'iframe']
      self.attributes = (ActionText::ContentHelper.allowed_attributes ||
                         ActionText::ContentHelper.sanitizer.class.allowed_attributes).to_a + EXTRA_ATTRIBUTES
    end

    def allowed_node?(node)
      return video_embed_iframe?(node) if node.name == 'iframe'

      super
    end

    private

    def base_tags
      (ActionText::ContentHelper.allowed_tags || ActionText::ContentHelper.sanitizer.class.allowed_tags).to_a
    end

    def video_embed_iframe?(node)
      node.ancestors.any? { |ancestor| ancestor.name == 'action-text-attachment' } &&
        node['src'].to_s.start_with?(NewfoundlandLabradorOnline::VideoBlock::EMBED_HOSTS[:youtube])
    end
  end
end
