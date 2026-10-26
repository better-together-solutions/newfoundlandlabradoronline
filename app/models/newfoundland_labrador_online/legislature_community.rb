# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Legislature communities: a Community subtype (STI on the type column).
  class LegislatureCommunity < BetterTogether::Community
    include NewfoundlandLabradorOnline::CommunitySubtype

    has_one :legislature_detail, class_name: 'NewfoundlandLabradorOnline::LegislatureDetail',
                                 foreign_key: :community_id, inverse_of: :community, dependent: :destroy
  end
end
