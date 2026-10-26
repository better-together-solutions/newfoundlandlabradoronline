# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Geography
    # Attaches a generated map image to a district: always as the stored default, and as the cover
    # (and so the card image) unless someone has uploaded their own, which is never replaced.
    class DistrictCover
      Result = Struct.new(:region, :status, keyword_init: true)

      def self.call(region:, io:, filename:)
        new(region:, io:, filename:).call
      end

      def initialize(region:, io:, filename:)
        @region = region
        @bytes = io.read
        @filename = filename
      end

      def call
        @region.default_cover_image.attach(blob)
        return keep_custom if @region.cover_image.attached? && !@region.generated_cover?

        @region.cover_image.attach(blob)
        @region.save!
        Result.new(region: @region, status: :attached)
      end

      private

      def keep_custom
        @region.save!
        Result.new(region: @region, status: :kept_custom)
      end

      def blob
        ActiveStorage::Blob.create_and_upload!(io: StringIO.new(@bytes), filename: @filename,
                                               content_type: 'image/jpeg', metadata: { 'generated' => true })
      end
    end
  end
end
