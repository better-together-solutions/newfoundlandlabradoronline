# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Seeds the electoral data packet (db/data/nl_regions) into an installed platform: districts, parties, elections,
  # members and party changes, then the Districts navigation link. Idempotent; each step can also be run alone.
  class ElectoralSeed
    class MissingPrerequisite < StandardError; end

    HEADER_AREA = 'platform-header'

    def self.call
      new.call
    end

    STEPS = %i[roles districts parties elections party_changes navigation].freeze

    # Returns a summary line per step, in the order they ran.
    def call
      check_platform
      ensure_province
      STEPS.index_with { |step| send(step) }
    end

    private

    def roles = "#{Civic::RoleSeeder.call.size} civic roles"
    def districts = summary(Geography::ProvincialDistrictLoader.new.call)
    def parties = summary(Geography::PoliticalPartyLoader.new.call)
    def elections = summary(Geography::ProvincialElectionLoader.new.call)
    def navigation = "districts link at position #{Geography::DistrictsNavigationItem.new.call.position}"

    def check_platform
      return if BetterTogether::Platform.exists?(host: true) &&
                BetterTogether::NavigationArea.exists?(identifier: HEADER_AREA)

      raise MissingPrerequisite, 'Set up the platform first (setup wizard, or better_together:load_seed)'
    end

    # The province lives in CE's geography reference data; planting it makes no external requests.
    def ensure_province
      Province.state_for('nl')
    rescue ActiveRecord::RecordNotFound
      BetterTogether::SeedCatalog::GeographyCatalog.plant_all
      Province.state_for('nl')
    end

    def party_changes
      result = Geography::PartyChangeLoader.new.call
      mismatches = result.roster_mismatches
      raise MissingPrerequisite, "Roster does not match the packet: #{mismatches.join('; ')}" if mismatches.any?

      summary(result)
    end

    def summary(result)
      counts = result.to_h.except(:roster_mismatches).transform_values { |v| v.is_a?(Array) ? v.size : v }
      counts.map { |key, value| "#{key}=#{value}" }.join(' ')
    end
  end
end
