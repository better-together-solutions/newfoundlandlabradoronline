# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Dated municipal status and external identifiers for BetterTogether::Geography::Settlement.
  module Settlement
    extend ActiveSupport::Concern

    included do
      has_many :statuses, class_name: 'BetterTogether::Geography::SettlementStatus', foreign_key: :settlement_id,
                          inverse_of: :settlement, dependent: :destroy
      has_many :identifiers, class_name: 'BetterTogether::Geography::SettlementIdentifier',
                             foreign_key: :settlement_id, inverse_of: :settlement, dependent: :destroy
    end

    class_methods do
      def with_identifier(scheme, value)
        joins(:identifiers).find_by(better_together_geography_settlement_identifiers: { scheme:, value: })
      end
    end

    # Uses the preloaded statuses when there are some (listings), otherwise one query.
    def status_on(date)
      return statuses.on(date).latest_first.first unless statuses.loaded?

      statuses.select { |status| status.in_force_on?(date) }.min_by(&:recency_key)
    end

    def current_status
      status_on(Time.zone.today)
    end

    def identifier_for(scheme)
      return identifiers.find_by(scheme:)&.value unless identifiers.loaded?

      identifiers.find { |identifier| identifier.scheme == scheme }&.value
    end
  end
end
