# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Makes a model locatable: one explicit location (a settlement, an address, ...) set through
  # nested attributes, the location form picker, or the API. The record needs no schema change.
  # Onboard a model by adding it to LocatableModels; see docs/locatable-onboarding.md.
  #
  # Deliberately a plain has_one and not CE's Locatable::One, which also makes a record Mappable and
  # so creates a map row per record.
  module Locatable
    extend ActiveSupport::Concern
    include LocationInterface

    included do
      has_one :location, class_name: 'BetterTogether::Geography::LocatableLocation', as: :locatable,
                         dependent: :destroy
      accepts_nested_attributes_for :location, allow_destroy: true, reject_if: :blank_location_attributes?
    end

    class_methods do
      # A record without a location of its own takes the place of +association+ (a post takes its community's).
      def inherit_location_from(association)
        self.location_inheritance = association
      end

      def extra_permitted_attributes
        locations = BetterTogether::Geography::LocatableLocation
        super + [{ location_attributes: locations.permitted_attributes(id: true, destroy: true) }]
      end
    end

    private

    # Same rule as CE's Locatable::One: ignore a new nested location when everything is blank.
    def blank_location_attributes?(attrs)
      attrs.blank? || attrs.values_at('id', 'name', 'location_id', 'location_type').all?(&:blank?)
    end
  end
end
