# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # The map on a settlement page, built on CE's map classes like the other host maps (NL Venues' VenueMap, CE's
  # EventCollectionMap): a Map subtype whose points come from the mapped records' own point producers, rendered by
  # the shared map partial and controller. Never saved; the helper (SettlementMapHelper) returns an unsaved one.
  #
  # Points: the settlement pin, then every located record (a model in LocatableModels) placed at a geocoded address
  # or building inside the settlement, through the viewer's policy scope. Records located at the settlement itself
  # are the pin and are not repeated. Each carries type, color and icon for the controller's pins, legend and clusters.
  class SettlementMap < BetterTogether::Geography::LocatableMap
    PLACE_TYPES = %w[BetterTogether::Address BetterTogether::Infrastructure::Building].freeze
    MAX_PER_TYPE = 500

    attr_accessor :settlement

    # ->(model) { policy scoped relation }; without it nothing but the pin is mapped.
    attr_writer :scope_for

    def center
      pin = settlement_space
      return super unless pin&.geocoded?

      RGeo::Geographic.spherical_factory(srid: 4326).point(pin.longitude, pin.latitude)
    end

    def leaflet_points
      @leaflet_points ||= [pin_point, *records.flat_map(&:located_leaflet_point)].compact
    end

    def spaces
      @spaces ||= [settlement_space, *records.filter_map { |record| record.location&.location&.space }].compact.uniq
    end

    # Located records with coordinates of their own, across every locatable model.
    def records
      @records ||= LocatableModels.models.flat_map { |model| records_for(model).to_a }
    end

    # The legend and cluster pie entries for the types that have points.
    def types
      present = records.to_set { |record| record.class.base_class.name }
      styled = LocatableModels.models.select { |model| present.include?(model.base_class.name) }
      styled.map { |model| type_entry(model) }
    end

    # Simplified GeoJSON of the settlement boundary, or nil when it has none.
    def boundary
      id = settlement_space&.id
      return unless id

      simplified = Arel.sql('ST_AsGeoJSON(ST_SimplifyPreserveTopology(boundary::geometry, 0.0001))')
      json = BetterTogether::Geography::Space.where(id:).where.not(boundary: nil).pick(simplified)
      json && JSON.parse(json)
    end

    private

    def type_entry(model)
      { key: model.base_class.name, label: model.model_name.human(count: 2) }.merge(LocatableModels.map_style(model))
    end

    def settlement_space
      settlement&.space
    end

    def pin_point
      space = settlement_space
      return unless space&.geocoded?

      link = "<a href='#{settlement_url}' class='text-decoration-none'><strong>#{ERB::Util.html_escape(settlement.name)}</strong></a>"
      space.to_leaflet_point.merge(label: link, popup_html: link)
    end

    def settlement_url
      BetterTogether::Engine.routes.url_helpers.polymorphic_path(settlement, locale: I18n.locale)
    end

    def records_for(model)
      return [] unless @scope_for

      placed = BetterTogether::Geography::LocatableLocation
               .where(locatable_type: model.base_class.name, location_type: PLACE_TYPES).select(:locatable_id)
      @scope_for.call(model).located_in(settlement).where(id: placed)
                .includes(location: { location: [:space, { building: :space }] }).limit(MAX_PER_TYPE)
    end
  end
end
