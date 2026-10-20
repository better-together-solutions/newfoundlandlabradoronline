# frozen_string_literal: true

require 'json'

module NewfoundlandLabradorOnline
  module Geography
    # Loads provincial electoral districts from the offline GeoJSON packet (built by management-tool
    # scripts/nl_regions_ingest.py). Idempotent: districts are matched on their nlo_ped identifier and versions on
    # (region, valid_from); a version's boundary is rewritten only when the packet's source checksum changed.
    class ProvincialDistrictLoader
      DEFAULT_PATH = Rails.root.join('db/data/nl_regions/provincial_electoral_districts_2015.geojson')
      PROVINCE = 'nl'
      Result = Struct.new(:created, :updated, :unchanged, keyword_init: true)

      def initialize(path: DEFAULT_PATH)
        @path = path
        @result = Result.new(created: [], updated: [], unchanged: [])
      end

      def call
        features = JSON.parse(File.read(@path)).fetch('features')
        BetterTogether::Geography::Region.without_auto_geocoding do
          ActiveRecord::Base.transaction { features.each { |feature| load_feature(feature) } }
        end
        @result
      end

      private

      def load_feature(feature)
        props = feature.fetch('properties')
        district = find_or_create_district(props.fetch('name'))
        version = district.versions.find_or_initialize_by(valid_from: props.fetch('valid_from'))
        return @result.unchanged << district.identifier if version.persisted? && same_source?(version, props)

        write_version(district, version, props, feature.fetch('geometry'))
      end

      def write_version(district, version, props, geometry)
        bucket = version.new_record? ? @result.created : @result.updated
        save_version(version, props)
        version.assign_boundary_from_geojson!(geometry)
        refresh_space(district, version)
        bucket << district.identifier
      end

      def find_or_create_district(name)
        identifier = ProvincialElectoralDistrict.identifier_for_name(name)
        state = Province.state_for(PROVINCE)
        district = ProvincialElectoralDistrict.find_by(identifier:)
        return associate(district, state) if district

        district = ProvincialElectoralDistrict.create!(identifier:, name:, state:, country: state.country,
                                                       privacy: 'public', protected: true)
        district.identifiers.create!(scheme: 'nlo_ped', value: identifier)
        district
      end

      def associate(district, state)
        district.update!(state:, country: state.country) unless district.state_id == state.id
        district
      end

      def same_source?(version, props)
        version.source_sha256 == props['source_sha256'] && version.boundary.present?
      end

      def save_version(version, props)
        version.update!(name: props.fetch('name'), valid_to: props['valid_to'], authority: props.fetch('authority'),
                        source_url: props['source_url'], source_sha256: props['source_sha256'],
                        license: props['license'])
      end

      # Keep the region's space (the cache the placement job and maps read) in step with its newest current version.
      def refresh_space(district, version)
        return unless version.valid_to.nil?

        space = persisted_space(district) || create_space(district)
        sql = BetterTogether::Geography::Space.sanitize_sql_array(
          ['UPDATE better_together_geography_spaces SET boundary = v.boundary, ' \
           'latitude = ST_Y(v.point), longitude = ST_X(v.point) ' \
           'FROM (SELECT boundary, ST_PointOnSurface(boundary::geometry) AS point ' \
           'FROM region_versions WHERE id = ?) v WHERE better_together_geography_spaces.id = ?',
           version.id, space.id]
        )
        BetterTogether::Geography::Space.connection.execute(sql)
      end

      # Region#space auto-builds an unsaved space, so look the saved join up directly.
      def persisted_space(district)
        BetterTogether::Geography::GeospatialSpace.find_by(geospatial: district)&.space
      end

      def create_space(district)
        BetterTogether::Geography::Space.create!.tap do |space|
          BetterTogether::Geography::GeospatialSpace.create!(geospatial: district, space:)
        end
      end
    end
  end
end
