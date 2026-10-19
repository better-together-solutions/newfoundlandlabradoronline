# frozen_string_literal: true

require 'json'

module NewfoundlandLabradorOnline
  module Geography
    # Applies dated party changes (floor crossings) from the official House of Assembly packet built by management-tool
    # scripts/nl_assembly_ingest.py, then checks the packet's current roster against the loaded memberships. Idempotent.
    # Run after the elections load.
    class PartyChangeLoader
      DEFAULT_PATH = Rails.root.join('db/data/nl_regions/provincial_party_changes.json')
      JURISDICTION = 'provincial-nl'
      Result = Struct.new(:applied, :unchanged, :missing, :roster_mismatches, keyword_init: true)

      def initialize(path: DEFAULT_PATH)
        @path = path
        @result = Result.new(applied: 0, unchanged: 0, missing: [], roster_mismatches: [])
      end

      def call
        packet = JSON.parse(File.read(@path))
        @source_url = packet['source_url']
        ActiveRecord::Base.transaction { packet.fetch('party_changes').each { |change| apply(change) } }
        packet.fetch('roster').each { |entry| check_roster(entry) }
        @result
      end

      private

      def apply(change)
        person = find_person(change.fetch('member'))
        party = find_party(change['party_key'])
        return @result.missing << change['member'] unless person && party

        date = Date.iso8601(change.fetch('effective_on'))
        return @result.unchanged += 1 if in_party?(person, party, date)

        change_party(person, party, date, change)
      end

      def in_party?(person, party, date)
        person.party_memberships.on(date).chronological.last&.political_party_id == party.id
      end

      def change_party(person, party, date, change)
        person.party_memberships.on(date).chronological.last&.update!(ended_on: date, end_reason: change['reason'])
        person.party_memberships.find_or_initialize_by(political_party: party, started_on: date)
              .update!(start_reason: change['reason'], source_url: @source_url)
        @result.applied += 1
      end

      def check_roster(entry)
        person = find_person(entry.fetch('name'), entry['district'])
        current = person && current_party_key(person)
        return if current == entry['party_key']

        @result.roster_mismatches << "#{entry['name']}: roster #{entry['party_key'].inspect}, loaded #{current.inspect}"
      end

      def current_party_key(person)
        person.party_memberships.current.chronological.last&.political_party&.identifier
      end

      # By name, else by the sitting member of the roster's district with the same surname ("James" vs "Jim").
      def find_person(name, district = nil)
        BetterTogether::Person.find_by(identifier: "#{ProvincialElectionLoader::MEMBER_PREFIX}#{name.parameterize}") ||
          sitting_member(district, name.split.last)
      end

      def sitting_member(district, surname)
        return unless district

        identifier = ProvincialElectoralDistrict.identifier_for_name(district)
        region = ProvincialElectoralDistrict.find_by(identifier:)
        term = region.elected_terms.current.first if region
        term.person if term && term.person.name.split.last == surname
      end

      def find_party(key)
        key && PoliticalParty.find_by(jurisdiction: JURISDICTION, identifier: key)
      end
    end
  end
end
