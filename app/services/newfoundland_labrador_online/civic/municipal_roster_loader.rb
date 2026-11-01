# frozen_string_literal: true

require 'json'

module NewfoundlandLabradorOnline
  module Civic
    # Loads councils and their officials from an offline packet (db/data/nl_municipal). A dry run (the default) does
    # every step inside a transaction and rolls it back, so the counts are what an apply would do. Idempotent:
    # settlements, councils, seats, people and memberships are matched on natural keys. Only names, offices and dates
    # are loaded; no personal contact details.
    class MunicipalRosterLoader
      DEFAULT_PATH = Rails.root.join('db/data/nl_municipal/councils.json')
      ROLES = { 'head' => 'legislature_head', 'deputy_head' => 'legislature_deputy_head',
                'member' => 'legislature_member' }.freeze
      Result = Struct.new(:councils, :people, :offices, :missing_settlements, keyword_init: true)

      def initialize(path: DEFAULT_PATH, apply: false)
        @path = path
        @apply = apply
        @result = Result.new(councils: 0, people: 0, offices: 0, missing_settlements: [])
      end

      def call
        entries = JSON.parse(File.read(@path)).fetch('councils')
        ActiveRecord::Base.transaction do
          Civic.in_platform_zone { entries.each { |entry| load_council(entry) } }
          raise ActiveRecord::Rollback unless @apply
        end
        @result
      end

      private

      def writer
        @writer ||= Writer.new
      end

      def load_council(entry)
        settlement = find_settlement(entry)
        return @result.missing_settlements << entry.fetch('settlement') unless settlement

        record_identity(settlement, entry)
        community = MunicipalCouncil.call(settlement:, name: entry.fetch('council_name'),
                                          body_kind: entry.fetch('body_kind', 'council'),
                                          seat_count: entry['seat_count'], seats: entry.fetch('seats', []),
                                          member_title: entry.fetch('member_title', 'Councillor'))
        @result.councils += 1
        entry.fetch('officials').each { |official| load_official(settlement, community, official) }
      end

      def find_settlement(entry)
        csd = entry['statcan_csd']
        (csd && BetterTogether::Geography::Settlement.with_identifier('statcan_csd', csd)) ||
          BetterTogether::Geography::Settlement.friendly.find(entry.fetch('settlement'))
      rescue ActiveRecord::RecordNotFound
        nil
      end

      def record_identity(settlement, entry)
        csd = entry['statcan_csd']
        settlement.identifiers.find_or_create_by!(scheme: 'statcan_csd', value: csd) if csd
        status = entry['municipal_status']
        return unless status

        settlement.statuses.find_or_create_by!(municipal_status: status, valid_from: nil, valid_to: nil,
                                               authority: entry.fetch('status_authority'),
                                               source_url: entry['status_source_url'])
      end

      def load_official(settlement, community, official)
        person = person_for(settlement, official.fetch('name'))
        writer.hold_office(person:, community:, role: ROLES.fetch(official.fetch('role')),
                           from: official['from'] && Date.parse(official['from']),
                           to: official['to'] && Date.parse(official['to']),
                           title: official.fetch('title'), seat: seat_for(community, official['seat']))
        @result.offices += 1
      end

      def seat_for(community, name)
        name && CommunitySeat.find_by!(community:, name:)
      end

      def person_for(settlement, name)
        identifier = "nl-municipal-#{settlement.identifier}-#{name.parameterize}"
        existing = BetterTogether::Person.find_by(identifier:)
        return existing if existing

        @result.people += 1
        BetterTogether::Person.create!(identifier:, name:, privacy: 'public', locale: 'en')
      end
    end
  end
end
