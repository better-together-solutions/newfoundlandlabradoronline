# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Host-side API additions for BetterTogether::Api::V1::PostResource: the fields the
  # Corner Brook Online publisher needs that CE does not expose. Category identifiers, attachment
  # block ids, the cover image and featured video inputs, and the pinned created_at/updated_at are CE's.
  module PostResourceExtension
    EXTRA_FIELDS = %i[community_id published_at contributor_specs].freeze
    CREATE_ONLY_FIELDS = %i[contributor_specs].freeze

    def self.prepended(base)
      base.attributes :community_id, :contributor_specs
      base.singleton_class.prepend(ClassMethods)
    end

    # Adds the publisher fields to the writable set; contributors are create-only.
    module ClassMethods
      def creatable_fields(context)
        (super + EXTRA_FIELDS).uniq
      end

      def updatable_fields(context)
        (super + EXTRA_FIELDS - CREATE_ONLY_FIELDS).uniq
      end
    end
  end
end
