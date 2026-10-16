# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Host addition to BetterTogether::Content::Hero: set the background image from a base64 image sent
  # through the blocks API (background_image_data), since CE's API has no file field. The type comes
  # from the bytes, never from the client, and CE's own attachment validators still apply.
  module HeroBlock
    extend ActiveSupport::Concern

    included do
      attr_accessor :background_image_data, :background_image_filename

      before_validation :assign_background_image_data, if: -> { background_image_data.present? }
      validate :background_image_data_must_be_valid
      after_save { self.background_image_data = nil }
    end

    private

    def assign_background_image_data
      result = ImageInput.decode(background_image_data)
      @background_image_error = result.error
      return if result.error

      background_image_file.attach(io: StringIO.new(result.bytes), content_type: result.type,
                                   filename: ImageInput.filename(background_image_filename, result.type, 'hero'))
    end

    def background_image_data_must_be_valid
      errors.add(:background_image_data, @background_image_error) if @background_image_error
    end
  end
end
