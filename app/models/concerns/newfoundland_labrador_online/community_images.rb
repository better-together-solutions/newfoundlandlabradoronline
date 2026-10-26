# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Write-only API input for a community's logo, cover and profile images (base64, see BetterTogether::ImageInput).
  # CE's attachment validators and variants still apply on top.
  module CommunityImages
    extend ActiveSupport::Concern

    included do
      include ::BetterTogether::Base64ImageInput

      accepts_base64_image :logo_data, attachment: :logo, filename_field: :logo_filename, default_name: 'logo'
      accepts_base64_image :cover_image_data, attachment: :cover_image, filename_field: :cover_image_filename,
                                              default_name: 'cover'
      accepts_base64_image :profile_image_data, attachment: :profile_image, filename_field: :profile_image_filename,
                                                default_name: 'profile'
    end
  end
end
