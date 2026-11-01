# frozen_string_literal: true

require 'json'

module NewfoundlandLabradorOnline
  module Civic
    # Loads council election results from an offline packet (db/data/nl_municipal/elections.json). Matches each
    # elected candidate to the council office already loaded for them and records the candidacy as what the office
    # rests on. A dry run (the default) rolls back, so counts are what an apply would do. Idempotent.
    class MunicipalElectionLoader
      DEFAULT_PATH = Rails.root.join('db/data/nl_municipal/elections.json')
      OFFICE_ROLES = { 'mayor' => 'legislature_head', 'councillor' => 'legislature_member' }.freeze
      Result = Struct.new(:elections, :contests, :candidacies, :linked, :unlinked, :missing_councils,
                          keyword_init: true)

      def initialize(path: DEFAULT_PATH, apply: false)
        @path = path
        @apply = apply
        @result = Result.new(elections: 0, contests: 0, candidacies: 0, linked: 0, unlinked: [], missing_councils: [])
      end

      def call
        entries = JSON.parse(File.read(@path)).fetch('elections')
        ActiveRecord::Base.transaction do
          Civic.in_platform_zone { entries.each { |entry| load_election(entry) } }
          raise ActiveRecord::Rollback unless @apply
        end
        @result
      end

      private

      def load_election(entry)
        settlement = BetterTogether::Geography::Settlement.friendly.find(entry.fetch('settlement'))
        council = council_for(settlement)
        return @result.missing_councils << entry.fetch('settlement') unless council

        election = save_election(entry, council)
        entry.fetch('contests').each { |contest| load_contest(election, council, settlement, contest) }
      rescue ActiveRecord::RecordNotFound
        @result.missing_councils << entry.fetch('settlement')
      end

      def council_for(settlement)
        LegislatureCommunity.joins(:legislature_detail)
                            .find_by(legislature_details: { level: 'municipal',
                                                            jurisdiction_type: settlement.class.polymorphic_name,
                                                            jurisdiction_id: settlement.id })
      end

      def save_election(entry, council)
        election = Election.find_or_initialize_by(jurisdiction: 'municipal', community: council,
                                                  held_on: entry.fetch('date'))
        election.update!(kind: entry.fetch('kind', 'general'), source_url: entry['source_url'],
                         license: entry['license'])
        @result.elections += 1
        election
      end

      def load_contest(election, council, settlement, entry)
        contest = election.contests.find_or_initialize_by(office: entry.fetch('office'), region: nil,
                                                          community_seat: seat_for(council, entry['seat']))
        contest.update!(seats_available: entry.fetch('seats_available', 1))
        @result.contests += 1
        entry.fetch('candidates').each { |candidate| load_candidacy(contest, council, settlement, candidate) }
      end

      def seat_for(council, name)
        name && CommunitySeat.find_by!(community: council, name:)
      end

      def load_candidacy(contest, council, settlement, candidate)
        candidacy = contest.candidacies.find_or_initialize_by(candidate_name: candidate.fetch('name'))
        candidacy.update!(votes: candidate['votes'], elected: candidate.fetch('elected', false),
                          acclaimed: candidate.fetch('acclaimed', false))
        @result.candidacies += 1
        link_office(contest, council, settlement, candidacy) if candidacy.elected
      end

      def link_office(contest, council, settlement, candidacy)
        mandate = mandate_for(contest, council, settlement, candidacy)
        return @result.unlinked << candidacy.candidate_name unless mandate

        mandate.update!(conferred_by: candidacy)
        @result.linked += 1
      end

      def mandate_for(contest, council, settlement, candidacy)
        person = BetterTogether::Person.find_by(
          identifier: "nl-municipal-#{settlement.identifier}-#{candidacy.candidate_name.parameterize}"
        )
        return unless person

        BetterTogether::PersonCommunityMembership
          .where(member_id: person.id, joinable: council, role: Civic.role(OFFICE_ROLES.fetch(contest.office)))
          .order(:starts_at).last&.mandate
      end
    end
  end
end
