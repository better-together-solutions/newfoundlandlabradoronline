# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Host-side API additions for BetterTogether::Api::V1::EventResource: the hosting community and the cover image.
  # Only people who may host for the community (or platform managers) can name it as host.
  module EventResourceExtension
    EXTRA_FIELDS = %i[host_community_id cover_image_data cover_image_filename].freeze

    def self.prepended(base)
      base.attributes(*EXTRA_FIELDS)
      base.singleton_class.prepend(ClassMethods)
    end

    # Adds the fields to the writable set.
    module ClassMethods
      def creatable_fields(context)
        (super + EXTRA_FIELDS).uniq
      end

      def updatable_fields(context)
        (super + EXTRA_FIELDS).uniq
      end
    end

    def fetchable_fields
      super - %i[cover_image_data cover_image_filename]
    end

    def host_community_id=(value)
      raise JSONAPI::Exceptions::InvalidFieldValue.new(:host_community_id, value) unless may_host?(value)

      @model.host_community_id = value
    end

    private

    def may_host?(community_id)
      person = context[:current_user]&.person
      return false unless person
      return true if community_id.blank? || person.permitted_to?('manage_platform')

      person.valid_event_host_ids.include?(community_id.to_s)
    end
  end
end
