# frozen_string_literal: true

require 'json'

module NewfoundlandLabradorOnline
  module Civic
    # Loads ward boundaries onto council seats from an offline GeoJSON packet (see WardBoundaryFetcher). A dry run (the
    # default) does every step in a transaction and rolls it back. Idempotent: a seat's boundary is rewritten only when
    # the packet's source checksum changed.
    class WardBoundaryLoader
      DEFAULT_PATH = Rails.root.join('db/data/nl_municipal/st_johns_wards.geojson')
      Result = Struct.new(:created, :updated, :unchanged, :missing_seats, keyword_init: true)

      def initialize(path: DEFAULT_PATH, apply: false)
        @path = path
        @apply = apply
        @result = Result.new(created: [], updated: [], unchanged: [], missing_seats: [])
      end

      def call
        features = JSON.parse(File.read(@path)).fetch('features')
        ActiveRecord::Base.transaction do
          features.each { |feature| load_feature(feature) }
          raise ActiveRecord::Rollback unless @apply
        end
        @result
      end

      private

      def load_feature(feature)
        props = feature.fetch('properties')
        seat = find_seat(props)
        return @result.missing_seats << "#{props['settlement']}/#{props['seat']}" unless seat

        record = seat.boundary_record || seat.build_boundary_record
        return @result.unchanged << seat.name if unchanged?(record, props)

        write(record, props, feature.fetch('geometry'))
      end

      def write(record, props, geometry)
        bucket = record.new_record? ? @result.created : @result.updated
        record.update!(props.slice('authority', 'source_url', 'portal_url', 'license', 'source_sha256', 'fetched_on'))
        record.assign_boundary_from_geojson!(geometry)
        bucket << record.community_seat.name
      end

      def unchanged?(record, props)
        record.persisted? && record.source_sha256 == props['source_sha256'] && record.boundary.present?
      end

      def find_seat(props)
        settlement = BetterTogether::Geography::Settlement.friendly.find(props.fetch('settlement'))
        council = Municipality.for(settlement)&.council
        council && CommunitySeat.find_by(community: council, name: props.fetch('seat'))
      rescue ActiveRecord::RecordNotFound
        nil
      end
    end
  end
end
