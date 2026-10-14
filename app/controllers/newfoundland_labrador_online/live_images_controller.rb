# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Serves the cached latest camera frame from this host (same origin, so no CSP change) with short
  # public cache headers so a CDN or the browser absorbs most requests. Last-Modified and
  # X-Frame-Captured-At are the moment the camera took the frame, not when it was fetched.
  class LiveImagesController < ActionController::Base
    def show
      return head :not_found unless LiveImage.known?(params[:slug])

      frame = LiveImage.frame(params[:slug])
      frame ? render_frame(frame) : unavailable
    end

    private

    def render_frame(frame)
      expires_in 30.seconds, public: true, 's-maxage': 60, stale_while_revalidate: 120
      apply_time_headers(frame)
      send_data frame.bytes, type: 'image/jpeg', disposition: 'inline' if stale?(etag: frame.etag, public: true)
    end

    def apply_time_headers(frame)
      response.headers['Last-Modified'] = (frame.captured_at || frame.fetched_at).httpdate
      response.headers['X-Frame-Captured-At'] = frame.captured_at.iso8601 if frame.captured_at
    end

    def unavailable
      response.headers['Retry-After'] = '30'
      head :service_unavailable
    end
  end
end
