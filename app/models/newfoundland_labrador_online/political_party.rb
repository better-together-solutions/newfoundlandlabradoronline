# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # A party within one jurisdiction. A provincial party and its federal counterpart are separate records; whether
  # and how they are connected is modelled with the federal work.
  class PoliticalParty < BetterTogether::ApplicationRecord
    self.table_name = 'political_parties'
    FALLBACK_COLOR = '#6c757d'

    has_one_attached :logo
    has_many :memberships, class_name: 'NewfoundlandLabradorOnline::PartyMembership', dependent: :destroy,
                           inverse_of: :political_party
    has_many :elected_terms, class_name: 'NewfoundlandLabradorOnline::ElectedTerm', dependent: :nullify,
                             inverse_of: :political_party

    validates :jurisdiction, :identifier, :name, :short_name, presence: true
    validates :color, format: { with: /\A#\h{6}\z/ }, allow_nil: true

    # Party records and their logos are public reference data; CE's blob gate asks the record this.
    def privacy_public? = true

    def display_color
      color.presence || FALLBACK_COLOR
    end
  end
end
