# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Civic
    # The single write path for seats and party memberships, used by the loaders and the backfill. Every call is
    # idempotent (a membership is matched on member, community, role and start) and quiet: no notifications, no
    # association eligibility checks.
    class Writer
      END_REASONS = { 'next_election' => 'term_ended', 'term_ended' => 'term_ended',
                      'floor_crossing' => 'floor_crossing' }.freeze

      def initialize
        RoleSeeder.call
        @provisioner = Provisioner.new
      end

      attr_reader :provisioner

      # extra: candidacy:, end_reason:, state:
      def hold_seat(person:, region:, from:, to: nil, **extra)
        state = extra.delete(:state) || region.state
        write(person, provisioner.legislature!(state), 'legislature_member', [from, to],
              { kind: 'elected', seat: region, conferred_by: extra[:candidacy], title: 'MHA',
                end_reason: map(extra[:end_reason]) })
      end

      # extra: start_reason:, end_reason:, source_url:
      def join_party(person:, party:, from:, to: nil, **extra)
        write(person, provisioner.provision_party(party), 'party_member', [from, to],
              { kind: 'member', start_reason: extra[:start_reason], end_reason: map(extra[:end_reason]),
                source_url: extra[:source_url] })
      end

      def end_membership(membership, on:, reason:)
        membership.assign_attributes(ends_at: Civic.local_midnight(on), skip_notifications: true,
                                     skip_eligibility: true)
        membership.mandate.end_reason = map(reason)
        membership.save!
      end

      def map(reason)
        reason && END_REASONS.fetch(reason, reason)
      end

      private

      def write(person, community, role_identifier, window, mandate_attributes)
        membership = BetterTogether::PersonCommunityMembership.find_or_initialize_by(
          member_id: person.id, joinable: community, role: Civic.role(role_identifier),
          starts_at: Civic.local_midnight(window.first)
        )
        membership.assign_attributes(status: 'active', ends_at: Civic.local_midnight(window.last),
                                     skip_notifications: true, skip_eligibility: true)
        (membership.mandate || membership.build_mandate).assign_attributes(mandate_attributes)
        membership.save!
        membership
      end
    end
  end
end
