# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # A general election: one contest per district.
  class Election < BetterTogether::ApplicationRecord
    self.table_name = 'elections'

    belongs_to :state, class_name: 'BetterTogether::Geography::State', optional: true, inverse_of: :elections
    has_many :contests, class_name: 'NewfoundlandLabradorOnline::ElectoralContest', dependent: :destroy,
                        inverse_of: :election
    has_many :terms, class_name: 'NewfoundlandLabradorOnline::ElectedTerm', dependent: :destroy, inverse_of: :election

    validates :jurisdiction, :held_on, presence: true

    scope :latest_first, -> { order(held_on: :desc) }

    def year
      held_on.year
    end
  end
end
