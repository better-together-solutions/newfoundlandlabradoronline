# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Civic
    # Compares what the pages read from the civic model with the elected terms and party memberships they used to
    # read. Returns the differences; an empty list means the migration is faithful.
    class ParityReport
      def self.call
        new.call
      end

      def call
        Civic.in_platform_zone { checks.flat_map { |name| send(name) } }
      end

      private

      def checks
        %i[current_member_per_district party_on_each_term_start seats_per_party seats_per_election_and_party
           party_rosters terms_per_person]
      end

      def current_member_per_district
        old = ElectedTerm.current.pluck(:region_id, :person_id).to_h
        new = Roster.current_holdings.to_h { |h| [h.region_id, h.person_id] }
        diff('current member per district', old, new)
      end

      def party_on_each_term_start
        old = ElectedTerm.includes(person: :party_memberships).to_h do |term|
          [[term.person_id, term.started_on], term.party_on(term.started_on)&.id]
        end
        diff('party at each term start', old, holdings.to_h do |h|
          [[h.person_id, h.started_on], h.party_on(h.started_on)&.id]
        end)
      end

      def seats_per_party
        old = ElectedTerm.current.includes(person: :party_memberships).group_by { |t| t.party_on&.id }
        diff('seats per party now', old.transform_values(&:size), Roster.current_seats_by_party_id)
      end

      def seats_per_election_and_party
        old = ElectedTerm.group(:election_id, :party_name).count
        diff('seats per election and party', old, Roster.seats_by_election_and_party(Election.select(:id)))
      end

      def party_rosters
        old = PartyMembership.pluck(:political_party_id, :person_id, :started_on, :ended_on)
        new = PoliticalParty.where.not(community_id: nil).flat_map do |party|
          Roster.party_holdings(party).map { |h| [party.id, h.person_id, h.started_on, h.ended_on] }
        end
        diff('party rosters', old.sort_by(&:to_s), new.sort_by(&:to_s))
      end

      def terms_per_person
        old = ElectedTerm.group(:person_id).count
        diff('terms per person', old, holdings.group_by(&:person_id).transform_values(&:size))
      end

      def holdings
        @holdings ||= Roster.holdings_by_person(ElectedTerm.select(:person_id)).values.flatten
      end

      def diff(name, old, new)
        return [] if old == new

        ["#{name}: #{old.size} before, #{new.size} after, #{differing_keys(old, new)} differ"]
      end

      def differing_keys(old, new)
        return '?' unless old.is_a?(Hash) && new.is_a?(Hash)

        (old.keys | new.keys).count { |key| old[key] != new[key] }
      end
    end
  end
end
