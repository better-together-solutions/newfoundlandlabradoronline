# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Write-only API input for the post cover image (base64, see BetterTogether::ImageInput). CE's own cover image
  # validators and attachment handling still apply on top.
  module PostCoverImage
    extend ActiveSupport::Concern

    included do
      attr_accessor :cover_image_data, :cover_image_filename

      before_validation :assign_cover_image_data, if: -> { cover_image_data.present? }
      validate :cover_image_data_must_be_valid
      after_save { self.cover_image_data = nil }
    end

    private

    def assign_cover_image_data
      result = ::BetterTogether::ImageInput.decode(cover_image_data)
      @cover_image_error = result.error
      return if result.error

      self.cover_image = { io: StringIO.new(result.bytes),
                           filename: ::BetterTogether::ImageInput.filename(cover_image_filename, result.type, 'cover'),
                           content_type: result.type }
    end

    def cover_image_data_must_be_valid
      errors.add(:cover_image_data, @cover_image_error) if @cover_image_error
    end
  end
end
