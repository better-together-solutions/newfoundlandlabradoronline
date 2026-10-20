# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Links and small markup shared by every page that mentions a party.
  module PartiesHelper
    def party_path_for(party)
      newfoundland_labrador_online_party_path(party.jurisdiction, province_code(party), party.identifier,
                                              locale: I18n.locale)
    end

    # The party logo through CE's storage proxy (the direct storage redirect is blocked by the CSP in production).
    def party_logo_tag(party, **)
      return unless party.logo.attached?

      alt = t('newfoundland_labrador_online.parties.logo_alt', name: party.name)
      image_tag(storage_proxy_url_for(party.optimized_logo), alt:, **)
    end

    def party_chip(party)
      return t('newfoundland_labrador_online.districts.index.no_party') unless party

      link_to(party_path_for(party), class: 'text-decoration-none', id: dom_id(party, :chip)) do
        safe_join([tag.span('', class: 'd-inline-block align-middle rounded me-1',
                                style: "width: .75rem; height: .75rem; background: #{party.display_color}"),
                   party.short_name])
      end
    end

    # A member's avatar and name linked to their profile, like other person records (CE's mention partial).
    def member_mention(person, **)
      render('better_together/people/mention', person:, justify_content: 'start', flex_align_items: 'center', **)
    end

    # The candidate's name; an elected candidate is shown as their Person mention.
    def candidate_name(candidacy)
      person = candidacy.term&.person
      person ? member_mention(person) : candidacy.candidate_name
    end

    def district_link(region)
      link_to region.name, district_path_for(region)
    end
  end
end
