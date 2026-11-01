# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # The map on a municipality page: every ward boundary the council's seats carry, no pins. Never saved;
  # MunicipalitiesHelper returns an unsaved one.
  class WardMap < BetterTogether::Geography::LocatableMap
    SIMPLIFY = 'ST_SimplifyPreserveTopology(boundary::geometry, 0.0005)'
    EXTENT = 'ST_Extent(boundary::geometry)'

    attr_accessor :seat_boundaries

    # { seat_boundary_id => simplified GeoJSON geometry }
    def geometries
      @geometries ||= scope.pluck(:id, Arel.sql("ST_AsGeoJSON(#{SIMPLIFY})")).to_h { |id, json| [id, JSON.parse(json)] }
    end

    def leaflet_points
      []
    end

    def spaces
      []
    end

    def types
      []
    end

    def credit
      Geography::BoundaryCredit.for_seat_boundary(seat_boundaries.first)
    end

    def layers
      return [] unless credit

      [{ key: 'ward_boundaries', label: 'Ward boundaries', attribution: credit.label,
         attribution_url: credit.attribution_url }]
    end

    def center
      wkt = scope.pick(Arel.sql("ST_AsText(ST_Centroid(#{EXTENT}::geometry))"))
      return super unless wkt

      RGeo::Geographic.spherical_factory(srid: 4326).parse_wkt(wkt)
    end

    # [[south, west], [north, east]] of all the wards, for the map to fit; nil when none has a boundary.
    def viewport
      south, west, north, east = scope.pick(Arel.sql(
                                              "ARRAY[ST_YMin(#{EXTENT}::geometry), ST_XMin(#{EXTENT}::geometry), " \
                                              "ST_YMax(#{EXTENT}::geometry), ST_XMax(#{EXTENT}::geometry)]"
                                            ))
      return super unless south

      [[south, west], [north, east]].to_json
    end

    private

    def scope
      SeatBoundary.where(id: seat_boundaries.map(&:id)).where.not(boundary: nil)
    end
  end
end
