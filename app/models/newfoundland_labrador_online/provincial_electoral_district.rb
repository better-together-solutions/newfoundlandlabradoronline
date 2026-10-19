# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # A Newfoundland and Labrador provincial electoral district (one House of Assembly seat). Region STI subtype;
  # boundaries and name changes between redistributions live in RegionVersion.
  class ProvincialElectoralDistrict < BetterTogether::Geography::Region
    IDENTIFIER_PREFIX = 'nl-ped-'

    def self.identifier_for_name(name)
      "#{IDENTIFIER_PREFIX}#{name.parameterize}"
    end
  end
end
