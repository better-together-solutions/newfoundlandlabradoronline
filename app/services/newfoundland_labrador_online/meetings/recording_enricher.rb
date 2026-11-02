# frozen_string_literal: true

require 'digest'

module NewfoundlandLabradorOnline
  module Meetings
    # Applies provider metadata (see scripts/meeting_recordings_fetch.py in the management tool) to recordings: live
    # status, schedule, length and captions. A finished recording also sets its event's length, rounded up to 5 minutes.
    # Idempotent by video id; captions are rewritten only when the provider's file changed. Dry unless apply: true.
    class RecordingEnricher
      Result = Struct.new(:updated, :captions, :unmatched, keyword_init: true) do
        def counts = { updated:, captions:, unmatched: unmatched.size }
      end

      LIVE_STATUSES = {
        'was_live' => 'past', 'is_live' => 'live', 'is_upcoming' => 'upcoming', 'post_live' => 'live'
      }.freeze

      def initialize(metadata:, apply: false)
        @metadata = metadata
        @apply = apply
        @result = Result.new(updated: 0, captions: 0, unmatched: [])
      end

      def call
        @metadata.each do |ref, info|
          recordings = MeetingRecording.where(provider: 'youtube', provider_ref: ref).includes(:meeting, :captions).to_a
          @result.unmatched << ref if recordings.empty?
          recordings.each { |recording| enrich(recording, info) }
        end
        @result
      end

      private

      def enrich(recording, info)
        @result.updated += 1
        return unless @apply

        recording.update!(recording_attributes(info))
        sync_captions(recording, info['captions'] || {})
        fit_event_length(recording)
      end

      def recording_attributes(info)
        { live_status: LIVE_STATUSES.fetch(info['live_status'].to_s, 'past'), fetched_at: Time.current,
          scheduled_for: time_from(info['release_timestamp']), published_at: time_from(info['timestamp']),
          duration_seconds: info['duration'].presence&.to_i }
      end

      def time_from(epoch) = epoch.presence && Time.zone.at(epoch.to_i)

      def sync_captions(recording, captions)
        captions.each do |language, data|
          checksum = Digest::SHA256.hexdigest(data['vtt'].to_s)
          caption = recording.captions.find_or_initialize_by(language:)
          next if caption.raw_checksum == checksum

          caption.assign_attributes(source: data['source'], raw_checksum: checksum, fetched_at: Time.current,
                                    **cue_attributes(data['vtt']))
          caption.save!
          @result.captions += 1
        end
      end

      def cue_attributes(vtt)
        cues = Vtt.parse(vtt)
        { cues:, body: Vtt.plain_text(cues) }
      end

      def fit_event_length(recording)
        event = recording.meeting.event
        return unless event && recording.past? && recording.duration_seconds.to_i.positive?

        minutes = (recording.duration_seconds / 300.0).ceil * 5
        event.update!(duration_minutes: minutes) if event.duration_minutes != minutes
      end
    end
  end
end
