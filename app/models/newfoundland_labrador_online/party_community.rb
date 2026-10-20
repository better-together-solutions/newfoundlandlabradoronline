# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Party communities: a Community subtype (STI on the type column).
  class PartyCommunity < BetterTogether::Community
    include NewfoundlandLabradorOnline::CommunitySubtype
  end
end
