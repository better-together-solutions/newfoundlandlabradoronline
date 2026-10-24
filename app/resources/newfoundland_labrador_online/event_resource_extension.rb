# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Host-side API additions for BetterTogether::Api::V1::EventResource: the hosts (see EventHosting), the lifecycle
  # status (events are drafts, hidden from the public lists, until confirmed) and the cover image. As in the event
  # form, a host must be the person or a community they belong to; platform managers may name any host.
  module EventResourceExtension
    EXTRA_FIELDS = %i[hosts status cover_image_data cover_image_filename].freeze

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

    def hosts=(value)
      raise JSONAPI::Exceptions::InvalidFieldValue.new(:hosts, value) unless may_host?(value)

      @model.hosts = value
    end

    def status=(value)
      unless BetterTogether::Event.statuses.key?(value.to_s)
        raise JSONAPI::Exceptions::InvalidFieldValue.new(:status, value)
      end

      @model.status = value
    end

    private

    def may_host?(value)
      person = context[:current_user]&.person
      return false unless person
      return true if person.permitted_to?('manage_platform')

      allowed = person.valid_event_host_ids.map(&:to_s)
      parsed_host_ids(value).all? { |id| allowed.include?(id) }
    end

    def parsed_host_ids(value)
      value = JSON.parse(value) if value.is_a?(String)
      Array(value).map { |spec| spec.to_h.with_indifferent_access[:host_id].to_s }
    rescue JSON::ParserError
      []
    end
  end
end
