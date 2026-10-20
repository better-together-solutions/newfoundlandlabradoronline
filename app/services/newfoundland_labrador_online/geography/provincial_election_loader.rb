# frozen_string_literal: true

require 'json'

module NewfoundlandLabradorOnline
  module Geography
    # Loads provincial general-election results from the offline packet (built by management-tool
    # scripts/nl_elections_ingest.py). Idempotent: elections, contests, candidacies and terms are matched on their
    # natural keys. Elected candidates become Person records (one per name) with one dated legislature membership per
    # cycle; a term ends when the next election's winner for the district takes the seat (by-elections are not
    # loaded yet).
    class ProvincialElectionLoader
      DEFAULT_PATH = Rails.root.join('db/data/nl_regions/provincial_election_results.json')
      JURISDICTION = 'provincial'
      MEMBER_PREFIX = 'nl-mha-'
      PROVINCE = 'nl'
      PARTY_KEYS = { 'liberal' => 'liberal', 'pc' => 'pc', 'ndp' => 'ndp', 'alliance' => 'nl-alliance',
                     'nl alliance' => 'nl-alliance', 'independent' => 'independent', 'ind.' => 'independent' }.freeze
      LABEL = /\s*\((?<label>[^)]*)\)\z/
      Result = Struct.new(:elections, :contests, :candidacies, :terms, :missing_districts, keyword_init: true)

      def self.key(name)
        I18n.transliterate(name.to_s).downcase.gsub(/[^a-z0-9]+/, '')
      end

      def initialize(path: DEFAULT_PATH)
        @path = path
        @result = Result.new(elections: 0, contests: 0, candidacies: 0, terms: 0, missing_districts: [])
      end

      def writer
        @writer ||= Civic::Writer.new
      end

      def call
        packet = JSON.parse(File.read(@path)).fetch('elections')
        load_all(packet)
        @result
      end

      private

      def load_all(packet)
        ActiveRecord::Base.transaction do
          packet.each { |entry| load_election(entry) }
          close_terms
          build_memberships
        end
      end

      def state
        @state ||= Province.state_for(PROVINCE)
      end

      def districts
        @districts ||= ProvincialElectoralDistrict.where(state:).index_by { |district| self.class.key(district.name) }
      end

      def load_election(entry)
        election = Election.find_or_initialize_by(jurisdiction: JURISDICTION, state:, held_on: entry.fetch('date'))
        election.update!(source_url: entry['source_url'], source_revid: entry['source_revid'],
                         source_sha256: entry['source_sha256'], license: entry['license'])
        @result.elections += 1
        entry.fetch('districts').each { |row| load_contest(election, row) }
      end

      def load_contest(election, row)
        district = districts[self.class.key(row.fetch('district'))]
        return @result.missing_districts << row['district'] unless district

        contest = election.contests.find_or_initialize_by(region: district)
        contest.update!(turnout: row['turnout'])
        @result.contests += 1
        row.fetch('candidates').each { |candidate| load_candidacy(contest, candidate) }
      end

      # The results page files independents and small parties under "Other" with the label after the name.
      def name_and_party(candidate)
        raw = candidate.fetch('candidate')
        label = raw[LABEL, :label]
        party = label && PARTY_KEYS.key?(label.downcase) ? label : candidate.fetch('party')
        [raw.sub(LABEL, '').strip, PARTY_KEYS[party.downcase] == 'independent' ? 'Independent' : party]
      end

      def party_record(label)
        key = PARTY_KEYS[label.downcase]
        key && PoliticalParty.find_by(jurisdiction: JURISDICTION, state:, identifier: key)
      end

      def load_candidacy(contest, candidate)
        name, party_name = name_and_party(candidate)
        candidacy = contest.candidacies.find_or_initialize_by(candidate_name: name)
        candidacy.update!(party_name:, political_party: party_record(party_name), votes: candidate.fetch('votes'),
                          vote_share: candidate['share'], elected: candidate.fetch('elected'),
                          wikipedia_path: candidate['wikipedia_path'])
        @result.candidacies += 1
        load_term(contest, candidacy) if candidacy.elected
      end

      def load_term(contest, candidacy)
        writer.hold_seat(person: person_for(candidacy.candidate_name), region: contest.region,
                         from: contest.election.held_on, candidacy:, state:)
        @result.terms += 1
      end

      def person_for(name)
        clean = name.sub(/\s*\(.*\)\z/, '').strip
        identifier = "#{MEMBER_PREFIX}#{clean.parameterize}"
        BetterTogether::Person.find_by(identifier:) ||
          BetterTogether::Person.create!(identifier:, name: clean, privacy: 'public', locale: 'en')
      end

      def build_memberships
        Civic::ElectedPartyMemberships.new(writer, seat_memberships).call
      end

      def seat_memberships
        Civic::Roster.seat_memberships.includes(:mandate, :member).order(:starts_at)
      end

      # Each term ends when the district's next term starts; the newest stays open.
      def close_terms
        seat_memberships.group_by { |m| m.mandate.seat_id }.each_value do |memberships|
          memberships.each_cons(2) do |old, newer|
            writer.end_membership(old, on: Civic.local_date(newer.starts_at), reason: 'next_election')
          end
        end
      end
    end
  end
end
