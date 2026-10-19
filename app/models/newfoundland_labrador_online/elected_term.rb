# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # A person holding a district's seat after an election (the join between Person, district and election cycle).
  class ElectedTerm < BetterTogether::ApplicationRecord
    self.table_name = 'elected_terms'

    belongs_to :person, class_name: 'BetterTogether::Person', inverse_of: :elected_terms
    belongs_to :region, class_name: 'BetterTogether::Geography::Region', inverse_of: :elected_terms
    belongs_to :election, class_name: 'NewfoundlandLabradorOnline::Election', inverse_of: :terms
    belongs_to :candidacy, class_name: 'NewfoundlandLabradorOnline::Candidacy', inverse_of: :term
    belongs_to :political_party, class_name: 'NewfoundlandLabradorOnline::PoliticalParty', optional: true,
                                 inverse_of: :elected_terms

    validates :office, :party_name, :started_on, presence: true

    scope :current, -> { where(ended_on: nil) }
    scope :latest_first, -> { order(started_on: :desc) }

    # The party the member belonged to on a date: their membership then (floor crossings), else the party elected.
    def party_on(date = Time.zone.today)
      held = person.party_memberships.select { |m| m.started_on <= date && (m.ended_on.nil? || m.ended_on > date) }
      held.max_by(&:started_on)&.political_party || political_party
    end
  end
end
