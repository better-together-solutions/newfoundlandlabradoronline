# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Lets the posts index list one settlement's posts: /posts?settlement=<identifier>. The set is
  # Post.located_in (located at the settlement, at an address within it, or inheriting the location of
  # a community located there), always through the policy scope so visibility never widens.
  module SettlementPosts
    extend ActiveSupport::Concern

    prepended do
      before_action :load_settlement, only: :index
    end

    private

    def load_settlement
      return if params[:settlement].blank?

      @settlement = BetterTogether::Geography::Settlement.find_by!(identifier: params[:settlement].to_s.downcase)
    end

    def index_scope_params
      @settlement ? { settlement: @settlement.identifier } : super
    end

    def index_heading
      return super unless @settlement

      t('newfoundland_labrador_online.settlement_posts.title', name: @settlement.name)
    end

    def policy_scoped_resources
      scope = super
      @settlement ? scope.located_in(@settlement) : scope
    end
  end
end
