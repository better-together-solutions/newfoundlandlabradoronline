# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # A named place on a body (an at-large seat, an officer post, or one held on behalf of a member organisation).
  class CommunitySeat < BetterTogether::ApplicationRecord
    self.table_name = 'community_seats'
    KINDS = %w[at_large representing officer ex_officio].freeze

    belongs_to :community, class_name: 'BetterTogether::Community'
    belongs_to :represents_community, class_name: 'BetterTogether::Community', optional: true
    has_many :mandates, as: :seat, class_name: 'NewfoundlandLabradorOnline::MembershipMandate',
                        dependent: :restrict_with_error

    validates :name, presence: true, uniqueness: { scope: :community_id }
    validates :kind, inclusion: { in: KINDS }
    validates :represents_community, presence: true, if: -> { kind == 'representing' }
    validates :represents_community, absence: true, unless: -> { kind == 'representing' }

    scope :ordered, -> { order(:position, :name) }
  end
end
