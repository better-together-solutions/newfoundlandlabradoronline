# frozen_string_literal: true

require 'net/http'

module NewfoundlandLabradorOnline
  # The latest camera frame for a community, fetched from a public source, cropped to 16:9 and
  # kept in the Rails cache so many viewers cost one upstream request a minute. If the source is
  # down the last good frame keeps being served.
  class LiveImage
    SOURCES = {
      'corner-brook' => ENV.fetch('LIVE_IMAGE_CORNER_BROOK_URL', 'https://ai.btsdev.ca/webhook/timelapse-current')
    }.freeze
    # Records that show a camera, by model and identifier.
    RECORDS = {
      'BetterTogether::Community' => { 'corner-brook-online' => 'corner-brook' },
      'BetterTogether::Geography::Settlement' => { 'corner-brook' => 'corner-brook' }
    }.freeze
    WIDTH = 1920
    HEIGHT = 1080
    TOP_OFFSET = 0.03 # share of the frame height skipped at the top, as for the post covers
    FRESH_FOR = 60.seconds
    MAX_BYTES = 8.megabytes
    OPEN_TIMEOUT = 3
    READ_TIMEOUT = 8
    Frame = Struct.new(:bytes, :fetched_at, :etag)

    class << self
      def slug_for(record)
        RECORDS.dig(record.class.name, record.try(:identifier))
      end

      def known?(slug)
        SOURCES.key?(slug)
      end

      # The cached frame, refreshed when older than FRESH_FOR; nil when nothing has ever been fetched.
      def frame(slug)
        return unless known?(slug)

        current = Rails.cache.read(key(slug))
        return current if current && Time.current - current.fetched_at < FRESH_FOR

        refresh(slug) || current
      end

      private

      def key(slug)
        "newfoundland_labrador_online/live_image/#{slug}"
      end

      def refresh(slug)
        bytes = process(download(SOURCES.fetch(slug)))
        frame = Frame.new(bytes, Time.current, Digest::SHA1.hexdigest(bytes))
        Rails.cache.write(key(slug), frame, expires_in: 1.day)
        frame
      rescue StandardError => e
        Rails.logger.warn("live image #{slug} not refreshed: #{e.class}: #{e.message}")
        nil
      end

      def download(url)
        uri = URI.parse(url)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                                       open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
          http.get(uri.request_uri)
        end
        raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
        raise 'image too large' if response.body.bytesize > MAX_BYTES

        response.body
      end

      # Only a real JPEG or PNG is kept; the frame gets the same 16:9 crop as the post covers (full width,
      # a little off the top, roof edge excluded), is resized to 1920x1080 and compressed.
      def process(bytes)
        type = Marcel::MimeType.for(StringIO.new(bytes))
        raise "unexpected content type #{type}" unless %w[image/jpeg image/png].include?(type)

        Tempfile.create(['live', '.img'], binmode: true) do |source|
          source.write(bytes)
          source.flush
          render(source.path)
        end
      end

      def render(path)
        pipeline = ImageProcessing::Vips.source(path).crop(*crop_box(path)).resize_to_fill(WIDTH, HEIGHT).convert('jpg')
        File.binread(pipeline.saver(quality: 80, strip: true, interlace: true).call.path)
      end

      # [left, top, width, height] of the 16:9 crop, matching the timelapse project's cover crop.
      def crop_box(path)
        image = Vips::Image.new_from_file(path)
        width = image.width
        height = image.height
        return [0, 0, (height * 16.0 / 9).round, height] if height * 16 < width * 9

        crop_height = (width * 9.0 / 16).round
        [0, [(height * TOP_OFFSET).floor, height - crop_height].min, width, crop_height]
      end
    end
  end
end
