# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Serves the cached latest camera frame from this host (same origin, so no CSP change) with short
  # public cache headers so a CDN or the browser absorbs most requests.
  class LiveImagesController < ActionController::Base
    def show
      return head :not_found unless LiveImage.known?(params[:slug])

      frame = LiveImage.frame(params[:slug])
      frame ? render_frame(frame) : unavailable
    end

    private

    def render_frame(frame)
      expires_in 30.seconds, public: true, 's-maxage': 60, stale_while_revalidate: 120
      response.headers['Last-Modified'] = frame.fetched_at.httpdate
      send_data frame.bytes, type: 'image/jpeg', disposition: 'inline' if stale?(etag: frame.etag, public: true)
    end

    def unavailable
      response.headers['Retry-After'] = '30'
      head :service_unavailable
    end
  end
end
