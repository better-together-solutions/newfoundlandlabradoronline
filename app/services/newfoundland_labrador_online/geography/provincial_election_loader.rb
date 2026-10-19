# frozen_string_literal: true

require 'json'

module NewfoundlandLabradorOnline
  module Geography
    # Loads provincial general-election results from the offline packet (built by management-tool
    # scripts/nl_elections_ingest.py). Idempotent: elections, contests, candidacies and terms are matched on their
    # natural keys. Elected candidates become Person records (one per name) with one ElectedTerm per cycle; a term
    # ends when the next election's winner for the district takes the seat (by-elections are not loaded yet).
    class ProvincialElectionLoader
      DEFAULT_PATH = Rails.root.join('db/data/nl_regions/provincial_election_results.json')
      JURISDICTION = 'provincial'
      MEMBER_PREFIX = 'nl-mha-'
      JURISDICTION_PARTIES = 'provincial-nl'
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

      def districts
        @districts ||= ProvincialElectoralDistrict.all.index_by { |district| self.class.key(district.name) }
      end

      def load_election(entry)
        election = Election.find_or_initialize_by(jurisdiction: JURISDICTION, held_on: entry.fetch('date'))
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
        key && PoliticalParty.find_by(jurisdiction: JURISDICTION_PARTIES, identifier: key)
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
        term = ElectedTerm.find_or_initialize_by(region: contest.region, election: contest.election, office: 'mha')
        term.update!(person: person_for(candidacy.candidate_name), candidacy:, party_name: candidacy.party_name,
                     political_party: candidacy.political_party, started_on: contest.election.held_on)
        @result.terms += 1
      end

      def person_for(name)
        clean = name.sub(/\s*\(.*\)\z/, '').strip
        identifier = "#{MEMBER_PREFIX}#{clean.parameterize}"
        BetterTogether::Person.find_by(identifier:) ||
          BetterTogether::Person.create!(identifier:, name: clean, privacy: 'public', locale: 'en')
      end

      # One membership per run of consecutive terms for the same party (a party change starts a new one).
      def build_memberships
        ElectedTerm.where.not(political_party_id: nil).order(:started_on).group_by(&:person_id).each_value do |terms|
          terms.slice_when { |a, b| a.political_party_id != b.political_party_id || a.ended_on != b.started_on }
               .each { |run| save_membership(run) }
        end
      end

      def save_membership(run)
        membership = PartyMembership.find_or_initialize_by(person_id: run.first.person_id,
                                                           political_party_id: run.first.political_party_id,
                                                           started_on: run.first.started_on)
        return if membership.end_reason == 'floor_crossing' # recorded by PartyChangeLoader; keep it

        membership.update!(ended_on: run.last.ended_on, start_reason: 'elected',
                           end_reason: run.last.ended_on && 'term_ended', source_url: run.first.election.source_url)
      end

      # Each term ends when the district's next term starts; the newest stays open.
      def close_terms
        ElectedTerm.order(:started_on).group_by(&:region_id).each_value do |terms|
          terms.each_cons(2) { |old, newer| old.update!(ended_on: newer.started_on, end_reason: 'next_election') }
        end
      end
    end
  end
end
