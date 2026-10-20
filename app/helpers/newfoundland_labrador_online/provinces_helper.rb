# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # URL province codes for records scoped to a province (their state_id), looked up once per request.
  module ProvincesHelper
    # The public page for a state: /g/provinces for a province, else the canonical /g/states.
    def state_page_path(state)
      key = state.province? ? NewfoundlandLabradorOnline::Province.code_for(state) : state.slug
      route = state.province? ? :newfoundland_labrador_online_province_path : :newfoundland_labrador_online_state_path
      public_send(route, key, locale: I18n.locale)
    end

    def province_code(record)
      @province_codes ||= BetterTogether::Geography::State.where("iso_code LIKE 'CA-%'").pluck(:id, :iso_code)
                                                          .to_h { |id, iso| [id, iso.delete_prefix('CA-').downcase] }
      @province_codes.fetch(record.state_id)
    end
  end
end
