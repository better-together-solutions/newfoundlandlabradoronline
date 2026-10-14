# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Host-side API additions for BetterTogether::Api::V1::PostResource: the fields the
  # Corner Brook Online publisher needs that CE does not yet expose. Remove the parts
  # CE ships natively (see docs/ce-api-mcp-discrepancies-*.md in management-tool).
  module PostResourceExtension
    EXTRA_FIELDS = %i[
      community_id published_at video_block_id category_identifiers contributor_specs
      cover_image_data cover_image_filename
    ].freeze
    CREATE_ONLY_FIELDS = %i[contributor_specs video_block_id].freeze

    def self.prepended(base)
      base.attributes :community_id, :video_block_id, :category_identifiers, :contributor_specs,
                      :cover_image_data, :cover_image_filename
      base.singleton_class.prepend(ClassMethods)
    end

    # Class-level overrides
    module ClassMethods
      def creatable_fields(context)
        (super + EXTRA_FIELDS).uniq
      end

      def updatable_fields(context)
        (super + EXTRA_FIELDS - CREATE_ONLY_FIELDS).uniq
      end
    end

    # Write-only inputs: video_block_id attaches the block at creation and the cover image fields
    # attach the image, so none of them is returned (cover_image_url shows the result).
    def fetchable_fields
      super - %i[video_block_id cover_image_data cover_image_filename]
    end
  end
end
