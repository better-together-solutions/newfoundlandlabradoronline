# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Attributes of a legislature community: its level, jurisdiction and size.
  class LegislatureDetail < BetterTogether::ApplicationRecord
    self.table_name = 'legislature_details'
    LEVELS = %w[municipal provincial federal].freeze
    BODY_KINDS = %w[legislature council lsd_committee].freeze

    belongs_to :community, class_name: 'NewfoundlandLabradorOnline::LegislatureCommunity',
                           inverse_of: :legislature_detail
    belongs_to :jurisdiction, polymorphic: true, optional: true

    validates :level, inclusion: { in: LEVELS }
    validates :body_kind, inclusion: { in: BODY_KINDS }
    validates :seat_count, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  end
end
