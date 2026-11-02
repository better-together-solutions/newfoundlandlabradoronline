# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # A public meeting of a civic body (a council, committee, board or legislature), as published by the body's host.
  # The meeting is the source of truth; its Event is the calendar projection, rewritten on every import.
  class Meeting < BetterTogether::ApplicationRecord
    self.table_name = 'meetings'

    KINDS = %w[council committee board sitting].freeze
    STATUSES = %w[scheduled cancelled held].freeze

    belongs_to :body, class_name: 'BetterTogether::Community'
    belongs_to :event, class_name: 'BetterTogether::Event', optional: true
    has_many :documents, class_name: 'NewfoundlandLabradorOnline::MeetingDocument', dependent: :destroy,
                         inverse_of: :meeting

    validates :kind, inclusion: { in: KINDS }
    validates :status, inclusion: { in: STATUSES }
    validates :source, :source_id, :title, :starts_at, presence: true
    validates :source_id, uniqueness: { scope: :source }

    scope :newest_first, -> { order(starts_at: :desc) }
    scope :upcoming, -> { where(starts_at: Time.current..).order(:starts_at) }

    def cancelled? = status == 'cancelled'
    def held? = status == 'held'
    def category = event&.categories&.first
  end
end
