# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Geography
    # Imports one settlement's boundary from OpenStreetMap (Nominatim), where CE's batch import searches by bare name.
    # Searches "name, province, country" (one request), accepts only an administrative boundary polygon, and refuses a
    # polygon that does not cover the settlement's own point. A dry run (the default) fetches and reports but writes
    # nothing. Records the same boundary_source CE does, so BoundaryCredit credits it.
    class SettlementBoundaryImport
      Result = Struct.new(:status, :query, :osm_type, :osm_id, :display_name, :geometry_type, :area_km2, :covers_point,
                          keyword_init: true)

      def initialize(settlement:, apply: false, force: false)
        @settlement = settlement
        @apply = apply
        @force = force
      end

      # status: :no_space, :already_has_boundary, :not_found, :not_a_boundary, :point_outside, :would_import, :imported
      def call
        space = @settlement.space
        blocked = blocked_status(space)
        return Result.new(status: blocked, query:) if blocked

        data = search
        return Result.new(status: :not_found, query:) unless data

        describe(data, space).tap { |result| import(space, data, result) }
      end

      def query
        [@settlement.name, @settlement.state&.name, @settlement.country&.name].compact_blank.join(', ')
      end

      private

      def spaces
        BetterTogether::Geography::Space
      end

      def blocked_status(space)
        return :no_space unless space&.persisted?

        :already_has_boundary if space.boundary.present? && !@force
      end

      def import(space, data, result)
        return unless result.status == :would_import && @apply

        write(space, data)
        result.status = :imported
      end

      def search
        Geocoder.search(query, lookup: :nominatim, params: { polygon_geojson: 1 }).first&.data
      end

      def describe(data, space)
        geometry = data['geojson']
        result = Result.new(query:, osm_type: data['osm_type'], osm_id: data['osm_id'],
                            display_name: data['display_name'], geometry_type: geometry&.dig('type'))
        unless data['class'] == 'boundary' && %w[Polygon MultiPolygon].include?(result.geometry_type)
          return result.tap { |r| r.status = :not_a_boundary }
        end

        measure(result, geometry, space)
      end

      def measure(result, geometry, space)
        area, covers = spaces.connection.select_rows(measure_sql(geometry, space)).first
        result.area_km2 = area.to_f.round(2)
        result.covers_point = covers
        result.status = covers ? :would_import : :point_outside
        result
      end

      def measure_sql(geometry, space)
        sql = 'WITH g AS (SELECT ST_MakeValid(ST_GeomFromGeoJSON(?)) AS geom) ' \
              'SELECT ST_Area(geom::geography) / 1000000.0, ' \
              'ST_Covers(geom, ST_SetSRID(ST_MakePoint(?, ?), 4326)) FROM g'
        spaces.sanitize_sql_array([sql, geometry.to_json, space.longitude.to_f, space.latitude.to_f])
      end

      def write(space, data)
        sql = 'UPDATE better_together_geography_spaces SET boundary = ' \
              'ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_GeomFromGeoJSON(?)), 3))::geography WHERE id = ?'
        spaces.connection.execute(spaces.sanitize_sql_array([sql, data['geojson'].to_json, space.id]))
        space.reload.update!(metadata: space.metadata.merge('boundary_source' => source(data)))
      end

      def source(data)
        { 'provider' => 'nominatim', 'osm_type' => data['osm_type'], 'osm_id' => data['osm_id'],
          'via' => 'settlement_boundary_import', 'fetched_at' => Time.current.iso8601 }
      end
    end
  end
end
