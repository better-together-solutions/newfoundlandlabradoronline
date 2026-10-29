# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # One candidate's result in a contest. Candidates are kept as names; only elected members become Person records.
  class Candidacy < BetterTogether::ApplicationRecord
    self.table_name = 'candidacies'

    belongs_to :electoral_contest, class_name: 'NewfoundlandLabradorOnline::ElectoralContest',
                                   inverse_of: :candidacies
    belongs_to :political_party, class_name: 'NewfoundlandLabradorOnline::PoliticalParty', optional: true,
                                 inverse_of: false
    has_one :mandate, as: :conferred_by, class_name: 'NewfoundlandLabradorOnline::MembershipMandate',
                      dependent: :nullify

    delegate :membership, to: :mandate, allow_nil: true

    # The person this candidacy elected, once a mandate rests on it.
    def member
      mandate&.membership&.member
    end

    validates :candidate_name, :party_name, :votes, presence: true
  end
end
