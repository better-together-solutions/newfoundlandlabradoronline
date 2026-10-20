# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # A person's membership of a party over a date range; a floor crossing ends one membership and starts another.
  class PartyMembership < BetterTogether::ApplicationRecord
    self.table_name = 'party_memberships'

    belongs_to :person, class_name: 'BetterTogether::Person', inverse_of: :party_memberships
    belongs_to :political_party, class_name: 'NewfoundlandLabradorOnline::PoliticalParty', inverse_of: :memberships

    validates :started_on, presence: true
    validate :ended_on_after_started_on

    scope :on, ->(date) { where(started_on: ..date).where('ended_on IS NULL OR ended_on > ?', date) }
    scope :current, -> { on(Time.zone.today) }
    scope :chronological, -> { order(:started_on) }

    private

    def ended_on_after_started_on
      return if ended_on.blank? || started_on.blank? || ended_on > started_on

      errors.add(:ended_on, :invalid)
    end
  end
end
