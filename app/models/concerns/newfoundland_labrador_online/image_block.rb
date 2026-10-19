# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Host addition to BetterTogether::Content::Image: use as an Action Text attachment so posts embed
  # a real block. Creation from base64 (media_data) is CE's.
  module ImageBlock
    extend ActiveSupport::Concern

    # Included at module level so the partial path methods below take precedence.
    include ActionText::Attachable

    def attachable_plain_text_representation(_caption = nil)
      caption.presence || '[Image]'
    end

    def to_attachable_partial_path
      'newfoundland_labrador_online/image_blocks/image_block'
    end

    def to_trix_content_attachment_partial_path
      'newfoundland_labrador_online/image_blocks/trix'
    end
  end
end
