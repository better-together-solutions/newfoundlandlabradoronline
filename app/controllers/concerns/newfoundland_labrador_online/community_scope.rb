# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Lets the events and posts indexes list one community's items: /events?community_id=<slug or id> (events it
  # hosts) and /posts?community_id=<slug or id>, the lists behind the community page Posts and Events tabs. The
  # set always goes through the policy scope so visibility never widens; filters, ordering and paging apply on top.
  module CommunityScope
    extend ActiveSupport::Concern

    prepended do
      before_action :load_scoped_community, only: :index
    end

    private

    def load_scoped_community
      return if params[:community_id].blank?

      @scoped_community = BetterTogether::Community.friendly.find(params[:community_id].to_s)
    end
  end
end
