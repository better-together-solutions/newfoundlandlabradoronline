# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Settlement maps are never persisted or managed through the map CRUD; this exists so the class follows the
  # same policy convention as the other map subtypes.
  class SettlementMapPolicy < BetterTogether::Geography::LocatableMapPolicy
    class Scope < BetterTogether::Geography::LocatableMapPolicy::Scope
    end
  end
end
