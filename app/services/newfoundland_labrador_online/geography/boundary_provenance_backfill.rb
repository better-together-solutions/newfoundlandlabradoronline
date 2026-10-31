# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Geography
    # Records where an already stored settlement boundary came from, so the map can credit it. Only fills a boundary
    # that has no recorded source, and only from an OSM object the caller names; never guesses one. Idempotent, and
    # a dry run unless apply is true.
    class BoundaryProvenanceBackfill
      Result = Struct.new(:status, :space, keyword_init: true)

      def initialize(settlement:, osm_type:, osm_id:, apply: false)
        @settlement = settlement
        @osm_type = osm_type.to_s
        @osm_id = osm_id.to_s
        @apply = apply
      end

      # status: :no_boundary, :already_sourced, :invalid_source, :would_update (dry run), :updated
      def call
        space = @settlement.space
        return Result.new(status: :no_boundary, space:) unless space&.boundary.present?
        return Result.new(status: :already_sourced, space:) if space.metadata.dig('boundary_source', 'osm_id').present?
        return Result.new(status: :invalid_source, space:) unless valid_source?
        return Result.new(status: :would_update, space:) unless @apply

        space.update!(metadata: space.metadata.merge('boundary_source' => source))
        Result.new(status: :updated, space:)
      end

      private

      def valid_source?
        BoundaryCredit::OSM_TYPES.include?(@osm_type) && @osm_id.match?(/\A\d+\z/)
      end

      def source
        { 'provider' => 'nominatim', 'osm_type' => @osm_type, 'osm_id' => @osm_id.to_i, 'via' => 'backfill',
          'recorded_at' => Time.current.iso8601 }
      end
    end
  end
end
