# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Host-side API additions for BetterTogether::Api::V1::PostResource: the fields the
  # Corner Brook Online publisher needs that CE does not expose. Category identifiers, attachment
  # block ids and the pinned created_at/updated_at are CE's.
  module PostResourceExtension
    EXTRA_FIELDS = %i[
      community_id published_at video_block_id contributor_specs cover_image_data cover_image_filename
    ].freeze
    CREATE_ONLY_FIELDS = %i[contributor_specs video_block_id].freeze

    def self.prepended(base)
      base.attributes :community_id, :video_block_id, :contributor_specs, :cover_image_data, :cover_image_filename
      base.singleton_class.prepend(ClassMethods)
    end

    # Adds the publisher fields to the writable set; contributors and the video are create-only.
    module ClassMethods
      def creatable_fields(context)
        (super + EXTRA_FIELDS).uniq
      end

      def updatable_fields(context)
        (super + EXTRA_FIELDS - CREATE_ONLY_FIELDS).uniq
      end
    end

    def fetchable_fields
      super - %i[video_block_id cover_image_data cover_image_filename]
    end
  end
end
