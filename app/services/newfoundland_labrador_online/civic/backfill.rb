# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Civic
    # Converts elected terms and party memberships into memberships with mandates. Idempotent (records are matched
    # on member, community, role and start). Dry run by default: everything happens in a transaction that is rolled
    # back unless write is true. Imports are quiet and skip association eligibility.
    class Backfill
      Result = Struct.new(:terms, :party_memberships, :created, :errors, keyword_init: true)

      def self.call(write: false)
        new.call(write:)
      end

      def call(write: false)
        @result = Result.new(terms: 0, party_memberships: 0, created: 0, errors: [])
        Civic.in_platform_zone { convert_all(write) }
        @result
      end

      private

      def convert_all(write)
        ActiveRecord::Base.transaction do
          Provisioner.call
          @writer = Writer.new
          ElectedTerm.includes(:region, :candidacy, :person).find_each { |term| convert_term(term) }
          PartyMembership.includes(:political_party, :person).find_each { |row| convert_party(row) }
          raise ActiveRecord::Rollback unless write
        end
      end

      def convert_term(term)
        guard(term) do
          @writer.hold_seat(person: term.person, region: term.region, from: term.started_on, to: term.ended_on,
                            candidacy: term.candidacy, end_reason: term.end_reason)
          @result.terms += 1
        end
      end

      def convert_party(row)
        guard(row) do
          @writer.join_party(person: row.person, party: row.political_party, from: row.started_on, to: row.ended_on,
                             start_reason: row.start_reason, end_reason: row.end_reason, source_url: row.source_url)
          @result.party_memberships += 1
        end
      end

      def guard(source)
        before = BetterTogether::PersonCommunityMembership.count
        yield
        @result.created += BetterTogether::PersonCommunityMembership.count - before
      rescue ActiveRecord::RecordInvalid => e
        @result.errors << "#{source.class.name.demodulize} #{source.id}: #{e.message}"
      end
    end
  end
end
