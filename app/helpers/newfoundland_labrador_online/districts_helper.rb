# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Map and popup helpers for the district pages.
  module DistrictsHelper
    # The HTML under a district's popup title on the listing map: kind, area and the date its boundary took effect.
    def district_popup_body(district, kind:)
      version = district.current_version
      lines = [tag.p(kind, class: 'mb-1 text-muted')]
      lines << tag.p(district_popup_facts(version), class: 'mb-0') if version
      safe_join(lines)
    end

    def district_map(district)
      NewfoundlandLabradorOnline::DistrictMap.find_or_initialize_by(identifier: "district-#{district.identifier}")
                                             .tap { |map| map.district = district }
    end

    private

    def district_popup_facts(version)
      scope = 'newfoundland_labrador_online.districts.show'
      area = t("#{scope}.area_km2", value: number_with_delimiter(version.area_km2.round))
      "#{area} · #{t("#{scope}.in_force_since")} #{l(version.valid_from, format: :long)}"
    end
  end
end
