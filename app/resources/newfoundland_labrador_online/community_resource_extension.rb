# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Host-side API additions for BetterTogether::Api::V1::CommunityResource: write-only base64 logo, cover and
  # profile images (CE returns their URLs), and the write-only contact_data (see ContactData).
  module CommunityResourceExtension
    EXTRA_FIELDS = %i[
      logo_data logo_filename cover_image_data cover_image_filename profile_image_data profile_image_filename
      contact_data
    ].freeze

    def self.prepended(base)
      base.attributes(*EXTRA_FIELDS)
      base.singleton_class.prepend(ClassMethods)
    end

    # Adds the image fields to the writable set.
    module ClassMethods
      def creatable_fields(context)
        (super + EXTRA_FIELDS).uniq
      end

      def updatable_fields(context)
        (super + EXTRA_FIELDS).uniq
      end
    end

    def fetchable_fields
      super - EXTRA_FIELDS
    end
  end
end
