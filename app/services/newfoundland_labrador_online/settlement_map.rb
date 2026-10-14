# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # The data behind a settlement page map: the settlement pin and boundary, and the located records inside
  # it that have coordinates of their own (placed at a geocoded address or building). Records located at the
  # settlement itself are the settlement pin, so they are not repeated. Types come from LocatableModels, so
  # a newly onboarded model appears on the map without changes here.
  class SettlementMap
    PLACE_TYPES = %w[BetterTogether::Address BetterTogether::Infrastructure::Building].freeze
    MAX_PER_TYPE = 500

    # scope_for: ->(model) { policy scoped relation }, url_for: ->(record) { path }
    def initialize(settlement, scope_for:, url_for:)
      @settlement = settlement
      @scope_for = scope_for
      @url_for = url_for
    end

    def as_json(*)
      { settlement: pin, boundary: boundary, types: types, items: items }
    end

    def pin
      space = @settlement.space
      return unless space&.geocoded?

      { name: @settlement.name, lat: space.latitude, lng: space.longitude, url: @url_for.call(@settlement) }
    end

    # Simplified GeoJSON of the settlement boundary, or nil when the settlement has none.
    def boundary
      id = @settlement.space&.id
      return unless id

      simplified = Arel.sql('ST_AsGeoJSON(ST_SimplifyPreserveTopology(boundary::geometry, 0.0001))')
      json = BetterTogether::Geography::Space.where(id:).where.not(boundary: nil).pick(simplified)
      json && JSON.parse(json)
    end

    def types
      LocatableModels.models.map do |model|
        { key: model.base_class.name, label: model.model_name.human(count: 2) }.merge(LocatableModels.map_style(model))
      end
    end

    def items
      LocatableModels.models.flat_map { |model| items_for(model) }
    end

    private

    def items_for(model)
      records_for(model).filter_map do |record|
        point = record.location&.location&.to_leaflet_point
        next unless point

        { type: model.base_class.name, lat: point[:lat], lng: point[:lng], title: label(record),
          url: @url_for.call(record) }
      end
    end

    def records_for(model)
      placed = BetterTogether::Geography::LocatableLocation
               .where(locatable_type: model.base_class.name, location_type: PLACE_TYPES).select(:locatable_id)
      @scope_for.call(model).located_in(@settlement).where(id: placed)
                .includes(location: :location).limit(MAX_PER_TYPE)
    end

    def label(record)
      (record.respond_to?(:title) ? record.title : record.to_s).to_s
    end
  end
end
