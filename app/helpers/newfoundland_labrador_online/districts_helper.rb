# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Map and popup helpers for the district pages.
  module DistrictsHelper
    # The HTML under a district's popup title on the listing map: kind, area and the date its boundary took effect.
    def district_popup_body(district, kind:, term: nil)
      version = district.current_version
      lines = [tag.p(kind, class: 'mb-1 text-muted')]
      lines << tag.p(member_line(term), class: 'mb-1') if term
      lines << tag.p(district_popup_facts(version), class: 'mb-0') if version
      safe_join(lines)
    end

    # The district's coloured area on the listing map: its current member's party colour, and a popup like the pin's.
    def district_overlay(district, term, kind:)
      party = term&.party_on
      path = newfoundland_labrador_online_district_path(district, locale: I18n.locale)
      title = link_to(tag.strong(district.name), path, class: 'text-decoration-none')
      body = district_popup_body(district, kind:, term:)
      { color: party&.display_color || NewfoundlandLabradorOnline::PoliticalParty::FALLBACK_COLOR,
        popup: tag.div(safe_join([tag.h3(title, class: 'h6 mb-1'), body]), class: 'map-popup').to_s }
    end

    def member_line(term)
      party = term.party_on
      "#{t('newfoundland_labrador_online.districts.show.member')}: #{term.person.name}" \
        "#{" (#{party.short_name})" if party}"
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
