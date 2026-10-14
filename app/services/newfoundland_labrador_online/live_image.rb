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
    COMMUNITIES = { 'corner-brook-online' => 'corner-brook' }.freeze
    FRESH_FOR = 60.seconds
    MAX_BYTES = 8.megabytes
    OPEN_TIMEOUT = 3
    READ_TIMEOUT = 8
    Frame = Struct.new(:bytes, :fetched_at, :etag)

    class << self
      def slug_for(community)
        COMMUNITIES[community&.identifier]
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

      # Only a real JPEG or PNG is kept; the frame is cropped to 16:9 (top anchored, keeps the sky) and downsized.
      def process(bytes)
        type = Marcel::MimeType.for(StringIO.new(bytes))
        raise "unexpected content type #{type}" unless %w[image/jpeg image/png].include?(type)

        Tempfile.create(['live', '.img'], binmode: true) do |source|
          source.write(bytes)
          source.flush
          pipeline = ImageProcessing::Vips.source(source.path).resize_to_fill(1280, 720, crop: :low)
          File.binread(pipeline.convert('jpg').saver(quality: 82, strip: true).call.path)
        end
      end
    end
  end
end
