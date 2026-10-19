# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # The race in one district at one election.
  class ElectoralContest < BetterTogether::ApplicationRecord
    self.table_name = 'electoral_contests'

    belongs_to :election, class_name: 'NewfoundlandLabradorOnline::Election', inverse_of: :contests
    belongs_to :region, class_name: 'BetterTogether::Geography::Region', inverse_of: :contests
    has_many :candidacies, -> { order(votes: :desc) }, class_name: 'NewfoundlandLabradorOnline::Candidacy',
                                                       dependent: :destroy, inverse_of: :electoral_contest

    def winner
      candidacies.find(&:elected)
    end

    def total_votes
      candidacies.sum(&:votes)
    end
  end
end
