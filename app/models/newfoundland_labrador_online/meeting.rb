# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # A public meeting of a civic body (a council, committee, board or legislature), as published by the body's host.
  # The meeting is the source of truth; its Event is the calendar projection, rewritten on every import.
  class Meeting < BetterTogether::ApplicationRecord
    # Embeddable in rich text (registered in AttachableRegistry); an event description holds a signed reference.
    include ActionText::Attachable

    self.table_name = 'meetings'

    KINDS = %w[council committee board sitting].freeze
    STATUSES = %w[scheduled cancelled held].freeze

    belongs_to :body, class_name: 'BetterTogether::Community'
    belongs_to :event, class_name: 'BetterTogether::Event', optional: true
    has_many :documents, class_name: 'NewfoundlandLabradorOnline::MeetingDocument', dependent: :destroy,
                         inverse_of: :meeting
    has_many :recordings, class_name: 'NewfoundlandLabradorOnline::MeetingRecording', dependent: :destroy,
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

    # Meetings are public records, so the attachable registry may always render them.
    def privacy_public? = true
    def visible? = true

    def to_attachable_partial_path = 'newfoundland_labrador_online/meetings/attachment'
    def to_trix_content_attachment_partial_path = 'newfoundland_labrador_online/meetings/attachment_trix'

    def attachable_plain_text_representation(_caption = nil)
      "#{title} (#{starts_at.to_date.iso8601})"
    end
  end
end
