# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # A Newfoundland and Labrador provincial electoral district (one House of Assembly seat). Region STI subtype;
  # boundaries and name changes between redistributions live in RegionVersion.
  class ProvincialElectoralDistrict < BetterTogether::Geography::Region
    include BetterTogether::Attachments::Images

    IDENTIFIER_PREFIX = 'nl-ped-'

    attachable_cover_image

    def self.identifier_for_name(name)
      "#{IDENTIFIER_PREFIX}#{name.parameterize}"
    end
  end
end
