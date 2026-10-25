# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # The events half of CommunityScope: with ?community_id= the events index lists the events that community hosts.
  module CommunityEvents
    private

    def policy_scoped_resources
      scope = super
      @scoped_community ? scope.where(id: @scoped_community.hosted_events.select(:id)) : scope
    end
  end
end
