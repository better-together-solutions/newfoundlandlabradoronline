# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Meetings
    # Keeps a meeting's recordings in step with the video links its source lists. Links no provider recognises are
    # ignored, and a recording matched by hand is never rewritten or removed.
    class RecordingSync
      def initialize(meeting, urls)
        @meeting = meeting
        @urls = Array(urls)
      end

      def call
        wanted = @urls.filter_map { |url| identify(url) }
        @meeting.recordings.select do |rec|
          rec.match_method == 'source_link' && wanted.exclude?([rec.provider, rec.provider_ref])
        end
                .each(&:destroy!)
        wanted.each { |provider, ref| upsert(provider, ref) }
      end

      private

      def identify(url)
        provider = VideoProvider.identify(url)
        [provider.key, provider.reference_from(url)] if provider
      end

      def upsert(key, ref)
        provider = VideoProvider::PROVIDERS.fetch(key).constantize
        recording = @meeting.recordings.find_or_initialize_by(provider: key, provider_ref: ref)
        return if recording.persisted? && recording.match_method == 'manual'

        recording.assign_attributes(watch_url: provider.watch_url(ref), embed_url: provider.embed_url(ref))
        recording.live_status = @meeting.starts_at > Time.current ? 'upcoming' : 'past' if recording.new_record?
        recording.save!
      end
    end
  end
end
