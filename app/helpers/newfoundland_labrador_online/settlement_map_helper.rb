# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # The map for a settlement page, scoped to what the viewer may see (like CE's events_map and communities_map).
  module SettlementMapHelper
    def settlement_map(settlement)
      identifier = "settlement-#{settlement.identifier}"
      NewfoundlandLabradorOnline::SettlementMap.find_or_initialize_by(identifier:).tap do |map|
        map.settlement = settlement
        map.scope_for = ->(model) { policy_scope(model) }
      end
    end
  end
end
