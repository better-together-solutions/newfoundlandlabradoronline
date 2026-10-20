# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Civic
    # Converts elected terms and party memberships into memberships with mandates. Idempotent (records are matched
    # on member, community, role and start). Dry run by default: everything happens in a transaction that is rolled
    # back unless write is true. Imports are quiet and skip association eligibility.
    class Backfill
      END_REASONS = { 'next_election' => 'term_ended', 'term_ended' => 'term_ended',
                      'floor_crossing' => 'floor_crossing' }.freeze
      Result = Struct.new(:terms, :party_memberships, :created, :errors, keyword_init: true)

      def self.call(write: false)
        new.call(write:)
      end

      def call(write: false)
        @result = Result.new(terms: 0, party_memberships: 0, created: 0, errors: [])
        ActiveRecord::Base.transaction do
          @provisioner = Provisioner.new
          @provisioner.call
          ElectedTerm.includes(:region, :candidacy, :person).find_each { |term| convert_term(term) }
          PartyMembership.includes(:political_party, :person).find_each { |row| convert_party(row) }
          raise ActiveRecord::Rollback unless write
        end
        @result
      end

      private

      def convert_term(term)
        legislature = @provisioner.legislature_for(term.region.state)
        save(term, legislature, 'legislature_member', [term.started_on, term.ended_on],
             kind: 'elected', seat: term.region, conferred_by: term.candidacy, title: term.office.upcase,
             end_reason: END_REASONS[term.end_reason])
        @result.terms += 1
      end

      def convert_party(row)
        save(row, row.political_party.community, 'party_member', [row.started_on, row.ended_on],
             kind: 'member', start_reason: row.start_reason, end_reason: END_REASONS[row.end_reason],
             source_url: row.source_url)
        @result.party_memberships += 1
      end

      def save(source, community, role_identifier, window, mandate_attributes)
        membership = find_membership(source, community, role_identifier, window.first)
        @result.created += 1 if membership.new_record?
        assign(membership, window.last, mandate_attributes)
        membership.save!
      rescue ActiveRecord::RecordInvalid => e
        @result.errors << "#{source.class.name.demodulize} #{source.id}: #{e.message}"
      end

      def assign(membership, to, mandate_attributes)
        membership.assign_attributes(status: 'active', ends_at: Civic.local_midnight(to),
                                     skip_notifications: true, skip_eligibility: true)
        (membership.mandate || membership.build_mandate).assign_attributes(mandate_attributes)
      end

      def find_membership(source, community, role_identifier, from)
        BetterTogether::PersonCommunityMembership.find_or_initialize_by(
          member: source.person, joinable: community, role: Civic.role(role_identifier),
          starts_at: Civic.local_midnight(from)
        )
      end
    end
  end
end
