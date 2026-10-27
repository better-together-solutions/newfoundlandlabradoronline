# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Organization communities: a Community subtype (STI on the type column).
  class OrganizationCommunity < BetterTogether::Community
    include BetterTogether::CommunitySubtype
  end
end
