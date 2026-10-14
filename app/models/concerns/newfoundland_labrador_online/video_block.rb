# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Host additions to BetterTogether::Content::VideoBlock: vertical (9x16) video, and
  # use as an Action Text attachment so posts embed a real block rather than iframe HTML.
  module VideoBlock
    extend ActiveSupport::Concern

    ASPECT_RATIOS = %w[16x9 4x3 1x1 9x16].freeze
    EMBED_HOSTS = { youtube: 'https://www.youtube-nocookie.com/embed/' }.freeze

    # Included at module level so the partial path methods below take precedence.
    include ActionText::Attachable

    included do
      # CE validates against its own 3-ratio list, so swap that validator for ours.
      validator = _validators[:aspect_ratio].find { |v| v.is_a?(ActiveModel::Validations::InclusionValidator) }
      if validator
        _validators[:aspect_ratio].delete(validator)
        skip_callback(:validate, validator)
      end
      validates :aspect_ratio, inclusion: { in: ASPECT_RATIOS }
    end

    # Privacy-enhanced embed URL for attachments (CE's embed_url uses youtube.com).
    def attachment_embed_url
      return embed_url unless provider == :youtube

      embed_url.sub(%r{\Ahttps://www\.youtube\.com/embed/}, EMBED_HOSTS[:youtube])
    end

    def portrait?
      aspect_ratio == '9x16'
    end

    def attachable_plain_text_representation(_caption = nil)
      '[Video]'
    end

    def to_attachable_partial_path
      'newfoundland_labrador_online/video_blocks/video_block'
    end

    def to_trix_content_attachment_partial_path
      'newfoundland_labrador_online/video_blocks/trix'
    end
  end
end
