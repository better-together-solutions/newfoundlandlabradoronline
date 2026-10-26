# frozen_string_literal: true

module BetterTogether
  # The events map pins sessions, not the series that groups them: a series sits at the same place as its sessions and
  # would only add a duplicate pin. Prepended to EventCollectionMap's class method.
  module EventSeriesMap
    def records(visible_scope = nil)
      super.where(series: false)
    end
  end
end
