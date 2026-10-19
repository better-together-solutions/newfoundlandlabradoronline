# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # The map at the top of a geospatial listing page (districts, regions, settlements, states, countries, continents).
  # One pin per listed record that has coordinates, with a popup (linked title plus an HTML body), and the outline of
  # every listed record that has a boundary. Built on CE's map classes and never saved; ListingMapHelper builds it.
  class ListingMap < BetterTogether::Geography::LocatableMap
    RELATIVE_TOLERANCE = 0.01
    MIN_PART_SHARE = 0.0005
    COORDINATE_DECIMALS = 3 # about 100 m, enough for an overview map and a fraction of the payload

    attr_accessor :records, :url_for, :popup_body, :tolerance, :overlay_for

    def leaflet_points
      @leaflet_points ||= records.filter_map { |record| point_for(record) }
    end

    def spaces
      @spaces ||= records.filter_map(&:space)
    end

    def types
      []
    end

    # A GeoJSON FeatureCollection of simplified outlines, or nil when no listed record has a boundary. Each outline is
    # simplified in proportion to its own size and drops parts under MIN_PART_SHARE of it (offshore islets), so a
    # Labrador district and a town both stay light and legible.
    def boundary
      @boundary ||= begin
        json = BetterTogether::Geography::Space.connection.select_value(boundary_sql)
        collection(json)
      end
    end

    # One coloured, clickable area per record that has a boundary when overlay_for is set. overlay_for maps a record to
    # { color:, popup: }; each overlay carries its simplified GeoJSON geometry.
    def overlays
      return [] unless overlay_for

      @overlays ||= begin
        geometries = BetterTogether::Geography::Space.connection.select_rows(overlay_sql).to_h
        records.filter_map { |record| overlay_for_record(record, geometries) }
      end
    end

    # [[south, west], [north, east]] around every outline and pin, or nil with fewer than two places to frame.
    def viewport
      return super if leaflet_points.size < 2 && boundary.nil?

      lats, lngs = framed_coordinates
      [[lats.min, lngs.min], [lats.max, lngs.max]].to_json
    end

    def center
      point = leaflet_points.first
      return super unless point

      RGeo::Geographic.spherical_factory(srid: 4326).point(point[:lng], point[:lat])
    end

    private

    # Latitudes and longitudes of every pin plus the corners of the combined outline.
    def framed_coordinates
      lats = leaflet_points.pluck(:lat)
      lngs = leaflet_points.pluck(:lng)
      west, south, east, north = boundary_extent
      [lats + [south, north].compact, lngs + [west, east].compact]
    end

    def point_for(record)
      point = record.space&.to_leaflet_point
      return unless point

      title = ERB::Util.html_escape(record.name)
      link = "<a href='#{url_for.call(record)}' class='text-decoration-none'><strong>#{title}</strong></a>"
      popup = "<div class='map-popup'><h3 class='h6 mb-1'>#{link}</h3>#{popup_body.call(record)}</div>"
      point.merge(label: link, popup_html: popup)
    end

    def overlay_for_record(record, geometries)
      json = geometries[record.space&.id]
      return unless json

      overlay_for.call(record).merge(geometry: JSON.parse(json))
    end

    def quoted_ids
      ids = spaces.map { |space| BetterTogether::Geography::Space.connection.quote(space.id) }
      ids.join(', ').presence || 'NULL'
    end

    def simplified_parts
      <<~SQL.squish
        ST_Collect(ST_SimplifyPreserveTopology(part, GREATEST(#{tolerance.to_f}, SQRT(total) * #{RELATIVE_TOLERANCE})))
      SQL
    end

    def parts_sql
      <<~SQL.squish
        SELECT id, (ST_Dump(boundary::geometry)).geom AS part, ST_Area(boundary::geometry) AS total
        FROM better_together_geography_spaces WHERE boundary IS NOT NULL AND id IN (#{quoted_ids})
      SQL
    end

    def boundary_sql
      "SELECT ST_AsGeoJSON(#{simplified_parts}, #{COORDINATE_DECIMALS}) " \
        "FROM (#{parts_sql}) parts WHERE ST_Area(part) >= total * #{MIN_PART_SHARE}"
    end

    def overlay_sql
      "SELECT id, ST_AsGeoJSON(#{simplified_parts}, #{COORDINATE_DECIMALS}) " \
        "FROM (#{parts_sql}) parts WHERE ST_Area(part) >= total * #{MIN_PART_SHARE} GROUP BY id"
    end

    def boundary_scope
      BetterTogether::Geography::Space.where(id: spaces.map(&:id)).where.not(boundary: nil)
    end

    def boundary_extent
      extent = 'ST_Extent(boundary::geometry)'
      corners = "ST_XMin(#{extent}), ST_YMin(#{extent}), ST_XMax(#{extent}), ST_YMax(#{extent})"
      box = boundary_scope.pick(Arel.sql(corners))
      box&.all? ? box : nil
    end

    def collection(json)
      return unless json

      geometry = JSON.parse(json)
      { type: 'FeatureCollection', features: [{ type: 'Feature', properties: {}, geometry: }] }
    end
  end
end
