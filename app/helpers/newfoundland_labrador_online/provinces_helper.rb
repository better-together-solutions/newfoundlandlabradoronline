# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # URL province codes for records scoped to a province (their state_id), looked up once per request.
  module ProvincesHelper
    def province_code(record)
      @province_codes ||= BetterTogether::Geography::State.where("iso_code LIKE 'CA-%'").pluck(:id, :iso_code)
                                                          .to_h { |id, iso| [id, iso.delete_prefix('CA-').downcase] }
      @province_codes.fetch(record.state_id)
    end
  end
end
