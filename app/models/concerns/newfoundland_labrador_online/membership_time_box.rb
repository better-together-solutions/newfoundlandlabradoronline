# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Time-boxes person-community memberships (starts_at, ends_at) so a role can be held in successive terms, and
  # applies community association eligibility. Memberships without dates behave exactly as before.
  module MembershipTimeBox
    extend ActiveSupport::Concern

    TIME_ZONE = 'America/St_Johns'

    # Window queries; .active narrows the CE status scope to memberships whose window includes now.
    module ActiveWindow
      def active
        super.held_on(Time.current)
      end

      def held_on(time)
        t = arel_table
        where(t[:starts_at].eq(nil).or(t[:starts_at].lteq(time))).where(t[:ends_at].eq(nil).or(t[:ends_at].gt(time)))
      end

      def overlapping(from, to)
        t = arel_table
        scope = all
        scope = scope.where(t[:starts_at].eq(nil).or(t[:starts_at].lt(to))) if to
        from ? scope.where(t[:ends_at].eq(nil).or(t[:ends_at].gt(from))) : scope
      end
    end

    prepended do
      singleton_class.prepend(ActiveWindow)
      attr_accessor :skip_notifications, :skip_eligibility

      has_one :mandate, class_name: 'NewfoundlandLabradorOnline::MembershipMandate', foreign_key: :membership_id,
                        inverse_of: :membership, dependent: :destroy, validate: true,
                        autosave: true
      # The window-aware overlap check below replaces CE's one-role-per-person uniqueness.
      validators_on(:role_id).grep(ActiveRecord::Validations::UniquenessValidator).each do |validator|
        _validators[:role_id].delete(validator)
        skip_callback(:validate, validator)
      end

      scope :current, -> { held_on(Time.current) }
      scope :former, -> { where.not(ends_at: nil).where(arel_table[:ends_at].lteq(Time.current)) }
      scope :upcoming, -> { where(arel_table[:starts_at].gt(Time.current)) }

      validate :window_is_ordered
      validate :holdings_do_not_overlap
      validate :community_associations_allow_membership, on: :create
      after_commit :schedule_window_cache_expiry, :end_dependent_memberships
    end

    class_methods do
      # Calendar dates are stored as local midnight in Newfoundland time.
      def local_midnight(date)
        ActiveSupport::TimeZone[TIME_ZONE].local(date.year, date.month, date.day)
      end
    end

    def current?(at: Time.current)
      (starts_at.nil? || starts_at <= at) && (ends_at.nil? || ends_at > at)
    end

    private

    def window_is_ordered
      return unless starts_at && ends_at && ends_at <= starts_at

      errors.add(:ends_at, :after_start, message: 'must be after the start')
    end

    def holdings_do_not_overlap
      return if member_id.blank? || joinable_id.blank? || role_id.blank?

      errors.add(:role_id, :taken, message: 'is already held in an overlapping period') if overlapping_holdings.exists?
    end

    def overlapping_holdings
      self.class.where(member_id:, joinable_id:, role_id:).where.not(id:).overlapping(starts_at, ends_at)
    end

    def community_associations_allow_membership
      return if skip_eligibility || !joinable.respond_to?(:eligibility_for) || member.nil?

      outcome = joinable.eligibility_for(member, on: starts_at || Time.current, invited: appointed_or_invited?)
      return if %i[member open invited].include?(outcome)

      errors.add(:base, "not eligible to join this community (#{outcome})")
    end

    def appointed_or_invited?
      return true if mandate && %w[appointed ex_officio].include?(mandate.kind)

      joinable.respond_to?(:invitations) &&
        joinable.invitations.where(invitee: member, status: %w[pending accepted]).exists?
    end

    def schedule_window_cache_expiry
      return unless saved_change_to_starts_at? || saved_change_to_ends_at?

      [starts_at, ends_at].compact.select(&:future?).each do |time|
        NewfoundlandLabradorOnline::ExpireMemberPermissionCacheJob.set(wait_until: time).perform_later(member_id)
      end
    end

    # Ending a membership ends dependent memberships in communities that cascade from it.
    def end_dependent_memberships
      return unless saved_change_to_ends_at? && ends_at && !remaining_in_source?

      joinable.cascading_associations.find_each do |association|
        dependents_of(association).find_each { |dependent| dependent.update!(ends_at:) }
      end
    end

    def dependents_of(association)
      t = self.class.arel_table
      association.target_community.person_community_memberships.where(member_id:)
                 .where(t[:ends_at].eq(nil).or(t[:ends_at].gt(ends_at)))
    end

    def remaining_in_source?
      self.class.where(member_id:, joinable_id:).where.not(id:).held_on(ends_at).exists?
    end

    def notify_member_of_creation_if_active
      super unless skip_notifications
    end

    def notify_member_of_activation
      super unless skip_notifications
    end

    def notify_member_of_role_update
      super unless skip_notifications
    end

    def notify_member_of_removal
      super unless skip_notifications
    end

    def schedule_notification_cleanup
      super unless skip_notifications
    end
  end
end
