# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Meetings
    # Attaches one provider video, with its metadata and captions, to a council meeting: the API behind the
    # management tool's meeting recording sync. The meeting is named by its source id or found by date (and body) and
    # must be unambiguous. Idempotent by video id; nothing is written unless apply: true.
    class RecordingAttacher
      ZONE = 'America/St_Johns'
      LANGUAGE = /\A[a-z]{2,3}(-[A-Za-z0-9]+)?\z/
      CAPTION_SOURCES = %w[youtube_auto youtube_manual].freeze
      TRACKED = %w[live_status scheduled_for published_at duration_seconds].freeze

      Result = Struct.new(:status, :error, :meeting, :captions, keyword_init: true) do
        def error? = error.present?
      end

      def initialize(video_id:, metadata:, selector:, apply: false)
        @video_id = video_id.to_s
        @metadata = metadata
        @selector = selector
        @apply = apply
      end

      def call
        return failure(:invalid_video_id) unless @video_id.match?(VideoProvider::Youtube::ID)
        return failure(:invalid_metadata) unless valid_metadata?

        meeting = locate
        return meeting if meeting.is_a?(Result)

        conflict = conflict_for(meeting)
        return failure(conflict, meeting) if conflict

        @apply ? attach(meeting) : preview(meeting)
      end

      private

      def failure(code, meeting = nil) = Result.new(error: code, meeting:, captions: 0)

      def locate
        scope = Meeting.includes(:recordings, :event)
        found = @selector[:source_id].present? ? scope.where(source_id: @selector[:source_id]) : by_date(scope)
        return failure(:meeting_not_found) if found.empty?

        found.size > 1 ? failure(:ambiguous_meeting) : found.first
      end

      def by_date(scope)
        day = Date.iso8601(@selector[:date].to_s)
        range = Time.find_zone!(ZONE).local(day.year, day.month, day.day).then { |from| from..from.end_of_day }
        scope = scope.where(starts_at: range)
        @selector[:body_key].present? ? scope.where(body_key: @selector[:body_key]) : scope
      rescue Date::Error
        Meeting.none
      end

      def conflict_for(meeting)
        return :video_on_other_meeting if elsewhere?(meeting)

        :meeting_has_other_recording if meeting.recordings.any? { |rec| rec.provider_ref != @video_id }
      end

      def elsewhere?(meeting)
        MeetingRecording.where(provider: 'youtube', provider_ref: @video_id).where.not(meeting_id: meeting.id).exists?
      end

      def preview(meeting)
        existing = meeting.recordings.any? { |rec| rec.provider_ref == @video_id }
        Result.new(status: existing ? 'would_update' : 'would_attach', meeting:, captions: captions.size)
      end

      def attach(meeting)
        before = nil
        created = false
        count = Meeting.transaction do
          recording = meeting.recordings.find_by(provider: 'youtube', provider_ref: @video_id)
          created = recording.nil?
          recording ||= create_recording(meeting)
          before = recording.attributes.slice(*TRACKED)
          enrich(recording).tap { refresh_event(meeting) }
        end
        Result.new(status: status_for(created, before, meeting, count), meeting:, captions: count)
      end

      def create_recording(meeting)
        provider = VideoProvider::Youtube
        meeting.recordings.create!(provider: 'youtube', provider_ref: @video_id, match_method: 'date_match',
                                   watch_url: provider.watch_url(@video_id), embed_url: provider.embed_url(@video_id),
                                   live_status: meeting.starts_at > Time.current ? 'upcoming' : 'past')
      end

      def enrich(_recording)
        RecordingEnricher.new(metadata: { @video_id => @metadata }, apply: true).call.captions
      end

      def refresh_event(meeting)
        event = meeting.reload.event
        return unless event

        event.update!(attachment_block_ids: RecordingBlock.new(event.platform, meeting).ids)
      end

      def status_for(created, before, meeting, count)
        return 'attached' if created

        after = meeting.recordings.reload.find { |rec| rec.provider_ref == @video_id }.attributes.slice(*TRACKED)
        before == after && count.zero? ? 'unchanged' : 'updated'
      end

      def captions = @metadata['captions'] || {}

      def valid_metadata?
        @metadata.is_a?(Hash) && captions.is_a?(Hash) && captions.all? { |lang, data| valid_caption?(lang, data) }
      end

      def valid_caption?(language, data)
        language.to_s.match?(LANGUAGE) && data.is_a?(Hash) && CAPTION_SOURCES.include?(data['source']) &&
          data['vtt'].to_s.start_with?('WEBVTT')
      end
    end
  end
end
