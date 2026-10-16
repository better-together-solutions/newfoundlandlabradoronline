# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Host additions to BetterTogether::Content::Image: creation from a base64 image through the
  # blocks API (media_data), a required caption for API-created images, and use as an Action Text
  # attachment so posts embed a real block.
  module ImageBlock
    extend ActiveSupport::Concern

    # Included at module level so the partial path methods below take precedence.
    include ActionText::Attachable

    included do
      attr_accessor :media_data, :media_filename

      before_validation :assign_media_data, if: -> { media_data.present? }
      validate :media_data_must_be_valid
      validate :caption_required_for_api_images
      after_save { self.media_data = nil }
    end

    def attachable_plain_text_representation(_caption = nil)
      caption.presence || '[Image]'
    end

    def to_attachable_partial_path
      'newfoundland_labrador_online/image_blocks/image_block'
    end

    def to_trix_content_attachment_partial_path
      'newfoundland_labrador_online/image_blocks/trix'
    end

    private

    def assign_media_data
      result = ImageInput.decode(media_data)
      @media_error = result.error
      return if result.error

      media.attach(io: StringIO.new(result.bytes), content_type: result.type,
                   filename: ImageInput.filename(media_filename, result.type, 'image'))
    end

    def media_data_must_be_valid
      errors.add(:media_data, @media_error) if @media_error
    end

    def caption_required_for_api_images
      errors.add(:caption, :blank) if media_data.present? && caption.blank?
    end
  end
end
