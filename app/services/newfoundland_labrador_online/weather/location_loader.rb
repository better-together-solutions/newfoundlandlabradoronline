# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Weather
    # Creates the weather sources and locations listed in config/weather/sources.yml. Idempotent: existing rows are
    # left as they are. A dry run reports what would be created. Creating a location queues its first refresh and
    # history backfill, so only apply when the weather Sidekiq queue is being worked.
    class LocationLoader
      Result = Struct.new(:created, :existing, :missing_settlements, keyword_init: true)
      CONFIG_PATH = Rails.root.join('config/weather/sources.yml')

      def initialize(config: YAML.load_file(CONFIG_PATH), apply: false)
        @config = config
        @apply = apply
      end

      def call
        result = Result.new(created: [], existing: [], missing_settlements: [])
        @config.each { |identifier, source_config| load_source(identifier, source_config, result) }
        result
      end

      private

      def load_source(identifier, source_config, result)
        source = BetterTogether::Weather::Source.find_by(identifier:)
        source ||= build_source(identifier, source_config)
        source.save! if @apply && source.new_record?
        source_config.fetch('locations').each do |settlement_identifier, attributes|
          load_location(source, settlement_identifier, attributes, result)
        end
      end

      def build_source(identifier, source_config)
        BetterTogether::Weather::Source.new(
          identifier:, adapter_key: source_config.fetch('adapter'), enabled: source_config.fetch('enabled', true),
          config: source_config.fetch('config', {})
        )
      end

      def load_location(source, settlement_identifier, attributes, result)
        settlement = BetterTogether::Geography::Settlement.find_by(identifier: settlement_identifier)
        return result.missing_settlements << settlement_identifier unless settlement

        label = "#{source.identifier}:#{settlement_identifier}"
        return result.existing << label if source.persisted? && source.locations.exists?(settlement:)

        result.created << label
        source.locations.create!(attributes.merge('settlement' => settlement)) if @apply
      end
    end
  end
end
