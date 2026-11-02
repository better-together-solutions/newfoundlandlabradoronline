# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # The captions of one recording in one language, as plain text and as timestamped cues (start_ms, end_ms, text).
  class RecordingCaption < BetterTogether::ApplicationRecord
    self.table_name = 'recording_captions'

    SOURCES = %w[youtube_auto youtube_manual].freeze
    AUTOMATIC = %w[youtube_auto].freeze

    belongs_to :recording, class_name: 'NewfoundlandLabradorOnline::MeetingRecording', inverse_of: :captions

    validates :language, :body, :raw_checksum, :fetched_at, presence: true
    validates :format, inclusion: { in: %w[vtt] }
    validates :source, inclusion: { in: SOURCES }
    validates :language, uniqueness: { scope: :recording_id }

    def automatic? = AUTOMATIC.include?(source)

    # One line per cue, each with its start time, for the plain text download.
    def transcript_text
      cues.map { |cue| "[#{Time.at(cue['start_ms'] / 1000).utc.strftime('%H:%M:%S')}] #{cue['text']}" }.join("\n")
    end
  end
end
