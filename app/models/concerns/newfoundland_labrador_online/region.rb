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
      has_many :contests, class_name: 'NewfoundlandLabradorOnline::ElectoralContest', foreign_key: :region_id,
                          inverse_of: :region, dependent: :destroy
      has_many :elected_terms, class_name: 'NewfoundlandLabradorOnline::ElectedTerm', foreign_key: :region_id,
                               inverse_of: :region, dependent: :destroy

      include NewfoundlandLabradorOnline::PrivatePrimaryCommunity
    end

    class_methods do
      def with_identifier(scheme, value)
        joins(:identifiers).find_by(region_identifiers: { scheme:, value: })
      end
    end

    # Uses the loaded versions when they were preloaded (listing pages), else asks the database.
    def version_on(date)
      return versions.on(date).chronological.last unless versions.loaded?

      versions.select { |v| v.valid_from <= date && (v.valid_to.nil? || v.valid_to >= date) }.max_by(&:valid_from)
    end

    def current_version
      version_on(Time.zone.today)
    end

    def identifier_for(scheme)
      identifiers.find_by(scheme:)&.value
    end
  end
end
