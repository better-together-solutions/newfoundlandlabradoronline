# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Keeps the civic communities (legislatures, parties, ...) out of CE's communities index and community pickers.
  # They stay reachable by their own URLs and through the civic pages.
  module CommunityPolicyScope
    CIVIC_TYPES = %w[NewfoundlandLabradorOnline::LegislatureCommunity NewfoundlandLabradorOnline::PartyCommunity
                     NewfoundlandLabradorOnline::ExecutiveCommunity NewfoundlandLabradorOnline::DepartmentCommunity
                     NewfoundlandLabradorOnline::CommitteeCommunity
                     NewfoundlandLabradorOnline::OrganizationCommunity].freeze

    def resolve
      type = BetterTogether::Community.arel_table[:type]
      super.where(type.eq(nil).or(type.not_in(CIVIC_TYPES)))
    end
  end
end
