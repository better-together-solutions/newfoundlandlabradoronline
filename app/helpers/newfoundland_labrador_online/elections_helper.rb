# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Links to election pages.
  module ElectionsHelper
    def election_path_for(election)
      newfoundland_labrador_online_election_path(election.jurisdiction, election.year, locale: I18n.locale)
    end
  end
end
