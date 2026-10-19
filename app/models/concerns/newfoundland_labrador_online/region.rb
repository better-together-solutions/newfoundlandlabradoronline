# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Versioned boundaries and external identifiers for BetterTogether::Geography::Region (host-side first cut).
  module Region
    extend ActiveSupport::Concern

    included do
      has_many :versions, class_name: 'NewfoundlandLabradorOnline::RegionVersion', foreign_key: :region_id,
                          inverse_of: :region, dependent: :destroy
      has_many :identifiers, class_name: 'NewfoundlandLabradorOnline::RegionIdentifier', foreign_key: :region_id,
                             inverse_of: :region, dependent: :destroy
    end

    class_methods do
      def with_identifier(scheme, value)
        joins(:identifiers).find_by(nlo_region_identifiers: { scheme:, value: })
      end
    end

    def version_on(date)
      versions.on(date).chronological.last
    end

    def current_version
      version_on(Time.zone.today)
    end

    def identifier_for(scheme)
      identifiers.find_by(scheme:)&.value
    end
  end
end
