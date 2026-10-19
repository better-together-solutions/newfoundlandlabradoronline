# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # An external id for a region (Elections NL, Statistics Canada DGUID, Wikidata ...), unique per scheme.
  class RegionIdentifier < BetterTogether::ApplicationRecord
    SCHEMES = %w[nlo_ped statcan_dguid statcan_feduid wikidata osm_relation elections_nl].freeze

    self.table_name = 'nlo_region_identifiers'

    belongs_to :region, class_name: 'BetterTogether::Geography::Region', inverse_of: :identifiers

    validates :scheme, inclusion: { in: SCHEMES }
    validates :value, presence: true, uniqueness: { scope: :scheme }
    validates :scheme, uniqueness: { scope: :region_id }
  end
end
