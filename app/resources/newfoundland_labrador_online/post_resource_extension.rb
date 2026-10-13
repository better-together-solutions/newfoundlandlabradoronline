# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Host-side API additions for BetterTogether::Api::V1::PostResource: the fields the
  # Corner Brook Online publisher needs that CE does not yet expose. Remove the parts
  # CE ships natively (see docs/ce-api-mcp-discrepancies-*.md in management-tool).
  module PostResourceExtension
    EXTRA_FIELDS = %i[
      community_id published_at video_url video_orientation legacy_video_embed
      category_identifiers contributor_specs
    ].freeze

    def self.prepended(base)
      base.attributes :community_id, :video_url, :video_orientation, :legacy_video_embed,
                      :category_identifiers, :contributor_specs
      base.singleton_class.prepend(ClassMethods)
    end

    # Class-level overrides
    module ClassMethods
      def creatable_fields(context)
        (super + EXTRA_FIELDS).uniq
      end

      def updatable_fields(context)
        (super + EXTRA_FIELDS - %i[contributor_specs]).uniq
      end
    end
  end
end
