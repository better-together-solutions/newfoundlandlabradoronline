# frozen_string_literal: true

module BetterTogether
  module Geography
    # An external id for a settlement (Statistics Canada CSD, Open Data NL, Wikidata ...), unique per scheme.
    class SettlementIdentifier < BetterTogether::ApplicationRecord
      SCHEMES = %w[statcan_csd statcan_dguid nl_open_data_gcl wikidata osm_relation].freeze

      belongs_to :settlement, class_name: 'BetterTogether::Geography::Settlement', inverse_of: :identifiers

      validates :scheme, inclusion: { in: SCHEMES }
      validates :value, presence: true, uniqueness: { scope: :scheme }
      validates :scheme, uniqueness: { scope: :settlement_id }
    end
  end
end
