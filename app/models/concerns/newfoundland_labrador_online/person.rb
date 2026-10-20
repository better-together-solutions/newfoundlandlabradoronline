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

      after_create :hide_primary_community
    end

    private

    # A person's own community stays out of the public communities list. It is created at the profile's privacy
    # (the ceiling check needs that), then set private directly; the profile keeps its own privacy.
    def hide_primary_community
      community&.update_columns(privacy: 'private')
    end
  end
end
