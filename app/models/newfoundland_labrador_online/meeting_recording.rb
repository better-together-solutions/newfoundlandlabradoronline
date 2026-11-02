# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # A video of a meeting on a provider (see Meetings::VideoProvider). The provider keeps serving the video; only its
  # links, schedule and captions are kept here. A manually matched recording is never rewritten by an import.
  class MeetingRecording < BetterTogether::ApplicationRecord
    self.table_name = 'meeting_recordings'

    PROVIDERS = %w[youtube].freeze
    LIVE_STATUSES = %w[upcoming live past].freeze
    MATCH_METHODS = %w[source_link date_match manual].freeze

    belongs_to :meeting, class_name: 'NewfoundlandLabradorOnline::Meeting', inverse_of: :recordings
    has_many :captions, class_name: 'NewfoundlandLabradorOnline::RecordingCaption', foreign_key: :recording_id,
                        dependent: :destroy, inverse_of: :recording

    validates :provider, inclusion: { in: PROVIDERS }
    validates :live_status, inclusion: { in: LIVE_STATUSES }
    validates :match_method, inclusion: { in: MATCH_METHODS }
    validates :provider_ref, :watch_url, :embed_url, presence: true
    validates :provider_ref, uniqueness: { scope: %i[meeting_id provider] }

    def past? = live_status == 'past'
    def live? = live_status == 'live'
    def upcoming? = live_status == 'upcoming'
    def caption = captions.min_by(&:language)
  end
end
