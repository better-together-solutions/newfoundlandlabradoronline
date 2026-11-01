# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Geography
    # The credit a drawn boundary owes its source. Districts carry it on the region version (authority, source URL,
    # licence); a boundary imported from OpenStreetMap carries it as the space's boundary_source (provider and osm_id).
    # Returns nil when the source is unknown, so nothing is credited that is not recorded.
    class BoundaryCredit
      # One short line wrapped in a single link: the source, then the licence in brackets.
      Credit = Struct.new(:attribution, :attribution_url, :licence, keyword_init: true) do
        def label
          licence.present? ? "#{attribution} (#{licence})" : attribution
        end

        def to_h
          { attribution: label, attribution_url: }
        end
      end

      OSM_CREDIT = 'Boundary: OpenStreetMap'
      OSM_LICENCE = 'ODbL'
      OSM_TYPES = %w[node way relation].freeze

      def self.for_version(version)
        return unless version&.authority.present?

        Credit.new(attribution: version.authority, attribution_url: version.source_url, licence: version.license)
      end

      def self.for_seat_boundary(boundary)
        return unless boundary&.authority.present?

        url = boundary.portal_url || boundary.source_url
        Credit.new(attribution: "Boundary: #{boundary.authority}", attribution_url: url, licence: boundary.license)
      end

      def self.for_space(space)
        source = space&.metadata&.dig('boundary_source')
        return unless space&.boundary.present? && osm_source?(source)

        Credit.new(attribution: OSM_CREDIT, attribution_url: osm_url(source), licence: OSM_LICENCE)
      end

      def self.osm_source?(source)
        source.is_a?(Hash) && source['osm_id'].present? && OSM_TYPES.include?(source['osm_type'].to_s)
      end

      def self.osm_url(source)
        "https://www.openstreetmap.org/#{source['osm_type']}/#{Integer(source['osm_id'].to_s, 10)}"
      rescue ArgumentError, TypeError
        'https://www.openstreetmap.org/copyright'
      end

      private_class_method :osm_source?, :osm_url
    end
  end
end
