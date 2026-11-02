# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Meetings
    # The platform video block holding a meeting's recording, created once and reused on every import.
    class RecordingBlock
      def initialize(platform, meeting)
        @platform = platform
        @meeting = meeting
      end

      # Block ids to attach to the event description, empty when the meeting has no recording.
      def ids
        url = @meeting.recordings.min_by(&:created_at)&.watch_url
        return [] unless url

        block = BetterTogether::Content::VideoBlock.find_or_initialize_by(platform: @platform, id: block_id)
        # Public, so the attachable registry renders it for readers instead of the "under review" placeholder.
        block.update!(video_url: url, caption: @meeting.title, privacy: 'public') unless current?(block, url)
        @meeting.update!(details: @meeting.details.merge('video_block_id' => block.id))
        [block.id]
      end

      private

      def block_id = @meeting.details['video_block_id']

      def current?(block, url) = block.persisted? && block.video_url == url && block.privacy_public?
    end
  end
end
