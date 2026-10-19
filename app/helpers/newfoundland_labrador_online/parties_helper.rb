# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Links and small markup shared by every page that mentions a party.
  module PartiesHelper
    def party_path_for(party)
      newfoundland_labrador_online_party_path(party.jurisdiction, party.identifier, locale: I18n.locale)
    end

    def party_chip(party)
      return t('newfoundland_labrador_online.districts.index.no_party') unless party

      link_to(party_path_for(party), class: 'text-decoration-none', id: dom_id(party, :chip)) do
        safe_join([tag.span('', class: 'd-inline-block align-middle rounded me-1',
                                style: "width: .75rem; height: .75rem; background: #{party.display_color}"),
                   party.short_name])
      end
    end

    def district_link(region)
      link_to region.name, newfoundland_labrador_online_district_path(region, locale: I18n.locale)
    end
  end
end
