# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Elected terms held by a person (members of the House of Assembly).
  module Person
    extend ActiveSupport::Concern

    included do
      has_many :elected_terms, class_name: 'NewfoundlandLabradorOnline::ElectedTerm', foreign_key: :person_id,
                               inverse_of: :person, dependent: :destroy
      has_many :party_memberships, class_name: 'NewfoundlandLabradorOnline::PartyMembership', foreign_key: :person_id,
                                   inverse_of: :person, dependent: :destroy

      include NewfoundlandLabradorOnline::PrivatePrimaryCommunity
    end
  end
end
