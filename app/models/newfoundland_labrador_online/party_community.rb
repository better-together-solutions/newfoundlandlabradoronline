# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Party communities: a Community subtype (STI on the type column).
  class PartyCommunity < BetterTogether::Community
    include BetterTogether::CommunitySubtype

    has_one :political_party, class_name: 'NewfoundlandLabradorOnline::PoliticalParty', foreign_key: :community_id,
                              inverse_of: :community, dependent: :nullify
  end
end
