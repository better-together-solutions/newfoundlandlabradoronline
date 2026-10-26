# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Lets the events index list one settlement's events: /events?settlement=<identifier>, the list behind the
  # settlement page Events tab (like SettlementPosts for posts). The set is Event.located_in (at the settlement or
  # at an address within it), always through the policy scope so visibility never widens; the index's own filters,
  # ordering and paging apply on top.
  module SettlementEvents
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

      t('newfoundland_labrador_online.settlement_events.title', name: @settlement.name)
    end

    def policy_scoped_resources
      scope = super
      @settlement ? scope.located_in(@settlement) : scope
    end
  end
end
