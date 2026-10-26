# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Write-only API input for an event's cover image (base64, see BetterTogether::ImageInput).
  module EventImages
    extend ActiveSupport::Concern

    included do
      include ::BetterTogether::Base64ImageInput

      accepts_base64_image :cover_image_data, attachment: :cover_image, filename_field: :cover_image_filename,
                                              default_name: 'cover'
    end
  end
end
