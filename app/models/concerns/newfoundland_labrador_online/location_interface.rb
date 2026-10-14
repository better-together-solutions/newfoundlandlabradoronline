# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # The location interface shared by every locatable record (see LocatableModels): reading and
  # setting the location by settlement identifier, `located_in` scopes, and the effective location
  # (the record's own, else the one it inherits). It assumes `location` is a has_one LocatableLocation.
  # Models that already have CE's Locatable::One (events) include only this; others include Locatable.
  module LocationInterface
    extend ActiveSupport::Concern

    SETTLEMENT = 'BetterTogether::Geography::Settlement'

    included do
      class_attribute :location_inheritance, instance_accessor: false
      validate :settlement_identifier_must_exist
    end

    class_methods do
      # Records located in +place+ (a settlement, region, address, ...). A record with its own location
      # counts only through that location; a record without one counts through the location of the
      # record it inherits from (see Locatable.inherit_location_from).
      def located_in(place)
        direct = where(id: LocationQueries.locatable_ids(self, place))
        inherited = inherited_located_in(place)
        inherited ? direct.or(inherited) : direct
      end

      private

      def inherited_located_in(place)
        reflection = location_inheritance && reflect_on_association(location_inheritance)
        return unless reflection

        parent_ids = reflection.klass.located_in(place).select(:id)
        where.not(id: LocationQueries.explicitly_located_ids(self)).where(reflection.foreign_key => parent_ids)
      end
    end

    # The settlement identifier when the record is located at a settlement, else nil.
    def settlement_identifier
      place = location&.location
      place.identifier if place && place.class.base_class.name == SETTLEMENT
    end

    # Locates the record at the settlement with this identifier; blank clears the location.
    def settlement_identifier=(value)
      @settlement_identifier_error = nil
      if value.blank?
        clear_location
      elsif (settlement = SETTLEMENT.constantize.find_by(identifier: value.to_s.strip.downcase))
        (location || build_location).location = settlement
      else
        @settlement_identifier_error = value.to_s
      end
    end

    # The record's own place, else the place it inherits, else nil. A location that is only free text
    # still counts as the record's own, so it does not inherit.
    def effective_location
      return location.location if location

      parent = self.class.location_inheritance && public_send(self.class.location_inheritance)
      parent&.effective_location
    end

    def clear_location
      location&.mark_for_destruction
    end

    def settlement_identifier_must_exist
      errors.add(:settlement_identifier, :invalid) if @settlement_identifier_error
    end

    private :clear_location, :settlement_identifier_must_exist
  end
end
