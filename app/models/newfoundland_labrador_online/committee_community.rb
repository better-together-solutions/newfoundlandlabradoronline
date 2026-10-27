# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Committee communities: a Community subtype (STI on the type column).
  class CommitteeCommunity < BetterTogether::Community
    include BetterTogether::CommunitySubtype
  end
end
