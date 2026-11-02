# frozen_string_literal: true

require 'uri'

module NewfoundlandLabradorOnline
  module Meetings
    module VideoProvider
      # YouTube links. The player is the privacy-enhanced (youtube-nocookie) embed, the same one CE's video block uses.
      module Youtube
        HOSTS = %w[youtube.com www.youtube.com m.youtube.com youtu.be www.youtu.be].freeze
        ID = /\A[\w-]{11}\z/

        module_function

        def key = 'youtube'
        def frame_origin = 'https://www.youtube-nocookie.com'
        def watch_url(ref) = "https://www.youtube.com/watch?v=#{ref}"
        def embed_url(ref) = "#{frame_origin}/embed/#{ref}"

        # The video id in a watch, short, live or embed link, or nil.
        def reference_from(url)
          uri = URI.parse(url.to_s)
          return unless uri.is_a?(URI::HTTPS) && HOSTS.include?(uri.host.to_s.downcase)

          candidate = candidate_id(uri)
          candidate if candidate&.match?(ID)
        rescue URI::InvalidURIError
          nil
        end

        def candidate_id(uri)
          return uri.path.delete_prefix('/') if uri.host.to_s.end_with?('youtu.be')

          segments = uri.path.split('/').compact_blank
          return segments.last if %w[live embed shorts].include?(segments.first)

          URI.decode_www_form(uri.query.to_s).to_h['v'] if segments == ['watch']
        end
      end
    end
  end
end
