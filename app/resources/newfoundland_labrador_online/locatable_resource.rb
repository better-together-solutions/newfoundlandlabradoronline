# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # API attribute for locatable records (see LocatableModels): `settlement_identifier` reads and sets the
  # settlement the record is located at; null clears it. An unknown identifier is rejected, never created.
  module LocatableResource
    def self.prepended(base)
      base.attributes :settlement_identifier
      base.singleton_class.prepend(ClassMethods)
    end

    # Adds the attribute to the create and update field lists of the resource it is prepended to.
    module ClassMethods
      def creatable_fields(context)
        (super + [:settlement_identifier]).uniq
      end

      def updatable_fields(context)
        (super + [:settlement_identifier]).uniq
      end
    end
  end
end
