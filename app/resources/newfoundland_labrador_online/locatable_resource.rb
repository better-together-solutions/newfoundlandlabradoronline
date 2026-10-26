# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # API attribute for locatable records (see LocatableModels): `settlement_identifier` reads and sets the
  # settlement the record is located at; null clears it. An unknown identifier is rejected, never created.
  # `address_data` (write-only) locates the record at a street address instead (see LocationInterface#address_data).
  module LocatableResource
    FIELDS = %i[settlement_identifier address_data].freeze

    def self.prepended(base)
      base.attributes :settlement_identifier, :address_data
      base.singleton_class.prepend(ClassMethods)
    end

    def fetchable_fields
      super - %i[address_data]
    end

    # Adds the attributes to the create and update field lists of the resource it is prepended to.
    module ClassMethods
      def creatable_fields(context)
        (super + FIELDS).uniq
      end

      def updatable_fields(context)
        (super + FIELDS).uniq
      end
    end
  end
end
