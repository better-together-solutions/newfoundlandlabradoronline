# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Write-only API input for the post cover image. CE's API cannot upload files (no writable
  # image attribute, and direct uploads need a page-scoped token), so the publisher sends the
  # image as base64. The type comes from the bytes, never from the client; CE's own cover
  # image validators and attachment handling still apply on top.
  module PostCoverImage
    extend ActiveSupport::Concern

    MAX_BYTES = 5.megabytes
    ALLOWED_TYPES = { 'image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp' }.freeze

    included do
      attr_accessor :cover_image_data, :cover_image_filename

      before_validation :assign_cover_image_data, if: -> { cover_image_data.present? }
      validate :cover_image_data_must_be_valid
      after_save { self.cover_image_data = nil }
    end

    private

    def assign_cover_image_data
      @cover_image_error = nil
      bytes = decode_cover_image_data
      return unless bytes

      type = Marcel::MimeType.for(StringIO.new(bytes))
      return @cover_image_error = 'must be a JPEG, PNG or WebP image' unless ALLOWED_TYPES.key?(type)

      self.cover_image = { io: StringIO.new(bytes), filename: cover_image_name(type), content_type: type }
    end

    def decode_cover_image_data
      bytes = Base64.strict_decode64(cover_image_data)
      return bytes if bytes.bytesize <= MAX_BYTES

      @cover_image_error = "is too large (limit #{MAX_BYTES / 1.megabyte} MB)"
      nil
    rescue ArgumentError
      @cover_image_error = 'is not valid base64'
      nil
    end

    def cover_image_name(type)
      name = File.basename(cover_image_filename.to_s).gsub(/[^\w.-]/, '_').first(100)
      name.presence || "cover.#{ALLOWED_TYPES[type]}"
    end

    def cover_image_data_must_be_valid
      errors.add(:cover_image_data, @cover_image_error) if @cover_image_error
    end
  end
end
