# frozen_string_literal: true

module BetterTogether
  module Geography
    # The municipal standing a settlement held over a date range. Open ends mean "not recorded", not "unbounded".
    class SettlementStatus < BetterTogether::ApplicationRecord
      MUNICIPAL_STATUSES = %w[city town inuit_community_government local_service_district reserve
                              unincorporated].freeze
      INCORPORATED = %w[city town inuit_community_government].freeze

      belongs_to :settlement, class_name: 'BetterTogether::Geography::Settlement', inverse_of: :statuses

      validates :municipal_status, inclusion: { in: MUNICIPAL_STATUSES }
      validates :authority, presence: true
      validate :valid_to_after_valid_from

      scope :latest_first, -> { order(Arel.sql('valid_from DESC NULLS LAST')) }
      scope :on, lambda { |date|
        where('valid_from IS NULL OR valid_from <= ?', date).where('valid_to IS NULL OR valid_to >= ?', date)
      }
      scope :current, -> { on(Time.zone.today) }

      def in_force_on?(date)
        (valid_from.nil? || valid_from <= date) && (valid_to.nil? || valid_to >= date)
      end

      # Sorts the latest start first and unrecorded starts last, as `latest_first` does in SQL.
      def recency_key
        valid_from ? [0, -valid_from.jd] : [1, 0]
      end

      def incorporated?
        INCORPORATED.include?(municipal_status)
      end

      private

      def valid_to_after_valid_from
        return if valid_to.blank? || valid_from.blank? || valid_to >= valid_from

        errors.add(:valid_to, :invalid)
      end
    end
  end
end
