# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Executive communities: a Community subtype (STI on the type column).
  class ExecutiveCommunity < BetterTogether::Community
    include NewfoundlandLabradorOnline::CommunitySubtype
  end
end
