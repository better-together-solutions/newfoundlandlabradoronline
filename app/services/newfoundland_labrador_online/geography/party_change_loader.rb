# frozen_string_literal: true

require 'json'

module NewfoundlandLabradorOnline
  module Geography
    # Applies dated party changes (floor crossings) from the official House of Assembly packet built by management-tool
    # scripts/nl_assembly_ingest.py, then checks the packet's current roster against the loaded memberships. Idempotent.
    # Run after the elections load.
    class PartyChangeLoader
      DEFAULT_PATH = Rails.root.join('db/data/nl_regions/provincial_party_changes.json')
      JURISDICTION = 'provincial'
      PROVINCE = 'nl'
      Result = Struct.new(:applied, :unchanged, :missing, :roster_mismatches, keyword_init: true)

      def initialize(path: DEFAULT_PATH)
        @path = path
        @result = Result.new(applied: 0, unchanged: 0, missing: [], roster_mismatches: [])
      end

      def call
        Civic.in_platform_zone do
          packet = JSON.parse(File.read(@path))
          @source_url = packet['source_url']
          ActiveRecord::Base.transaction { packet.fetch('party_changes').each { |change| apply(change) } }
          packet.fetch('roster').each { |entry| check_roster(entry) }
          @result
        end
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

      def writer
        @writer ||= Civic::Writer.new
      end

      def in_party?(person, party, date)
        Civic::Roster.party_membership_on(person, date)&.joinable_id == party.community_id
      end

      def change_party(person, party, date, change)
        previous = Civic::Roster.party_membership_on(person, date)
        writer.end_membership(previous, on: date, reason: change['reason']) if previous
        writer.join_party(person:, party:, from: date, start_reason: change['reason'], source_url: @source_url)
        @result.applied += 1
      end

      def check_roster(entry)
        person = find_person(entry.fetch('name'), entry['district'])
        current = person && current_party_key(person)
        return if current == entry['party_key']

        @result.roster_mismatches << "#{entry['name']}: roster #{entry['party_key'].inspect}, loaded #{current.inspect}"
      end

      def current_party_key(person)
        membership = Civic::Roster.party_membership_on(person, Time.current)
        membership && PoliticalParty.find_by(community_id: membership.joinable_id)&.identifier
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
        holding = Civic::Roster.current_holdings(region_ids: [region.id]).first if region
        holding.person if holding && holding.person.name.split.last == surname
      end

      def find_party(key)
        key && PoliticalParty.find_by(jurisdiction: JURISDICTION, state: Province.state_for(PROVINCE), identifier: key)
      end
    end
  end
end
