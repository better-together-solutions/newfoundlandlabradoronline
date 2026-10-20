# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # What a membership rests on: an election, an appointment or an ex officio entitlement, the seat it fills and why
  # it ended. Dates live on the membership.
  class MembershipMandate < BetterTogether::ApplicationRecord
    self.table_name = 'membership_mandates'
    KINDS = %w[elected acclaimed appointed ex_officio].freeze
    END_REASONS = %w[defeated retired resigned died term_ended shuffled dissolved replaced_by_member].freeze

    belongs_to :membership, class_name: 'BetterTogether::PersonCommunityMembership', inverse_of: :mandate
    belongs_to :seat, polymorphic: true, optional: true
    belongs_to :conferred_by, polymorphic: true, optional: true

    validates :kind, inclusion: { in: KINDS }
    validates :end_reason, inclusion: { in: END_REASONS }, allow_nil: true
    validates :membership_id, uniqueness: true
    validate :representative_belongs_to_represented_community

    private

    def representative_belongs_to_represented_community
      return unless representing_seat? && membership&.member_id && !membership.skip_eligibility

      errors.add(:seat, 'requires a current membership in the community this seat represents') unless represented?
    end

    def representing_seat?
      seat.is_a?(CommunitySeat) && seat.represents_community_id.present?
    end

    def represented?
      BetterTogether::PersonCommunityMembership
        .where(member_id: membership.member_id, joinable_id: seat.represents_community_id)
        .held_on(membership.starts_at || Time.current).exists?
    end
  end
end
