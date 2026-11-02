# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # A document of a meeting that stays on the host's server; only its link is kept here.
  class MeetingDocument < BetterTogether::ApplicationRecord
    self.table_name = 'meeting_documents'

    KINDS = %w[agenda agenda_package minutes additional].freeze
    FORMATS = %w[pdf html].freeze

    belongs_to :meeting, class_name: 'NewfoundlandLabradorOnline::Meeting', inverse_of: :documents

    validates :kind, inclusion: { in: KINDS }
    validates :format, inclusion: { in: FORMATS }
    validates :title, :url, presence: true
    validates :url, format: { with: %r{\Ahttps://}, message: 'must be an https URL' }
    validates :url, uniqueness: { scope: %i[meeting_id kind format] }
  end
end
