# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Civic
    # Derives party memberships from the party each member was elected for: one membership per run of consecutive
    # terms for the same party (a party change starts a new one). A membership already ended by a floor crossing
    # is kept as recorded.
    class ElectedPartyMemberships
      def initialize(writer, seat_memberships)
        @writer = writer
        @seat_memberships = seat_memberships
      end

      def call
        @seat_memberships.group_by(&:member_id).each_value do |memberships|
          memberships.slice_when { |a, b| party_of(a) != party_of(b) || a.ends_at != b.starts_at }
                     .each { |run| save(run) if party_of(run.first) }
        end
      end

      private

      def save(run)
        first = run.first
        party = party_of(first)
        return if floor_crossed?(first, party)

        @writer.join_party(person: first.member, party:, from: Civic.local_date(first.starts_at),
                           to: Civic.local_date(run.last.ends_at), start_reason: 'elected',
                           end_reason: run.last.ends_at && 'term_ended', source_url: election_of(first).source_url)
      end

      def floor_crossed?(first, party)
        existing = BetterTogether::PersonCommunityMembership.find_by(
          member: first.member, joinable_id: party.community_id, role: Civic.role('party_member'),
          starts_at: first.starts_at
        )
        existing&.mandate&.end_reason == 'floor_crossing'
      end

      def party_of(membership)
        candidacy_of(membership)&.political_party
      end

      def election_of(membership)
        candidacy_of(membership).electoral_contest.election
      end

      def candidacy_of(membership)
        @candidacies ||= {}
        @candidacies[membership.id] ||= Candidacy.includes(:political_party, electoral_contest: :election)
                                                 .find_by(id: membership.mandate.conferred_by_id)
      end
    end
  end
end
