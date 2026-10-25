# frozen_string_literal: true

module BetterTogether
  # The events list shows sessions, not the series that groups them (the series appears as a mention on each
  # session's card). Prepended to EventsSearchFilter's class method so the list, and the community and settlement
  # tabs that embed it, leave series out; a series is still found by its own page and by the API.
  module EventSeriesListing
    def call(relation:, params:)
      super(relation: relation.where(series: false), params:)
    end
  end
end
