# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # The map on an electoral district page: the district outline from its current boundary version, no pins.
  # Never saved; DistrictsHelper returns an unsaved one.
  class DistrictMap < BetterTogether::Geography::LocatableMap
    attr_accessor :district

    def center
      point = Arel.sql('ST_AsText(ST_PointOnSurface(boundary::geometry))')
      wkt = boundary_scope&.pick(point)
      return super unless wkt

      RGeo::Geographic.spherical_factory(srid: 4326).parse_wkt(wkt)
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

    # Simplified GeoJSON of the current boundary, or nil when the district has none.
    def boundary
      simplified = Arel.sql('ST_AsGeoJSON(ST_SimplifyPreserveTopology(boundary::geometry, 0.002))')
      json = boundary_scope&.pick(simplified)
      json && JSON.parse(json)
    end

    # [[south, west], [north, east]] of the current boundary, for the map to fit; nil when it has none.
    def viewport
      box = Arel.sql('ARRAY[ST_YMin(boundary::geometry), ST_XMin(boundary::geometry), ' \
                     'ST_YMax(boundary::geometry), ST_XMax(boundary::geometry)]')
      south, west, north, east = boundary_scope&.pick(box)
      return super unless south

      [[south, west], [north, east]].to_json
    end

    private

    def boundary_scope
      version = district&.current_version
      return unless version

      NewfoundlandLabradorOnline::RegionVersion.where(id: version.id).where.not(boundary: nil)
    end
  end
end
