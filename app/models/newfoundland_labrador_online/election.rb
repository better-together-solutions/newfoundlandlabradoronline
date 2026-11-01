# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # A general election: one contest per district.
  class Election < BetterTogether::ApplicationRecord
    self.table_name = 'elections'

    KINDS = %w[general by_election plebiscite].freeze

    belongs_to :state, class_name: 'BetterTogether::Geography::State', optional: true, inverse_of: :elections
    # The body this election fills (a council); provincial elections are scoped by state instead.
    belongs_to :community, class_name: 'BetterTogether::Community', optional: true
    has_many :contests, class_name: 'NewfoundlandLabradorOnline::ElectoralContest', dependent: :destroy,
                        inverse_of: :election

    validates :jurisdiction, :held_on, presence: true
    validates :kind, inclusion: { in: KINDS }
    validates :community, presence: true, if: :municipal?

    scope :latest_first, -> { order(held_on: :desc) }

    def municipal?
      jurisdiction == 'municipal'
    end

    def year
      held_on.year
    end
  end
end
