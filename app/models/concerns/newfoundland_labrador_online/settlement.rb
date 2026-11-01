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

    def status_on(date)
      statuses.on(date).latest_first.first
    end

    def current_status
      status_on(Time.zone.today)
    end

    def identifier_for(scheme)
      identifiers.find_by(scheme:)&.value
    end
  end
end
