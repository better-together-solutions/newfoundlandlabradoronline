# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Department communities: a Community subtype (STI on the type column).
  class DepartmentCommunity < BetterTogether::Community
    include BetterTogether::CommunitySubtype
  end
end
