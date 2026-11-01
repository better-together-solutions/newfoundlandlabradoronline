# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # The race in one district at one election.
  class ElectoralContest < BetterTogether::ApplicationRecord
    self.table_name = 'electoral_contests'

    belongs_to :election, class_name: 'NewfoundlandLabradorOnline::Election', inverse_of: :contests
    OFFICES = %w[member mayor deputy_mayor councillor].freeze

    # A district contest has a region; a council contest has an office and, for a ward, a seat.
    belongs_to :region, class_name: 'BetterTogether::Geography::Region', optional: true, inverse_of: :contests
    belongs_to :community_seat, class_name: 'NewfoundlandLabradorOnline::CommunitySeat', optional: true
    has_many :candidacies, -> { order(votes: :desc) }, class_name: 'NewfoundlandLabradorOnline::Candidacy',
                                                       dependent: :destroy, inverse_of: :electoral_contest

    validates :office, inclusion: { in: OFFICES }
    validates :seats_available, numericality: { only_integer: true, greater_than: 0 }
    validates :region, presence: true, unless: -> { election&.municipal? }

    def winner
      winners.first
    end

    def winners
      candidacies.select(&:elected)
    end

    def total_votes
      candidacies.sum { |candidacy| candidacy.votes.to_i }
    end
  end
end
