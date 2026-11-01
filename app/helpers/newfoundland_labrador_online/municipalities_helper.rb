# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Links and labels for the municipality pages.
  module MunicipalitiesHelper
    def municipality_path_for(settlement)
      newfoundland_labrador_online_municipality_path(province_code(settlement), settlement, locale: I18n.locale)
    end

    def municipal_election_path_for(settlement, election)
      newfoundland_labrador_online_municipal_election_path(province_code(settlement), settlement, election.year,
                                                           locale: I18n.locale)
    end

    # A contest's heading: the office, with the ward when it is a ward seat.
    def contest_title(contest)
      office = t("newfoundland_labrador_online.municipal_elections.show.offices.#{contest.office}")
      seat = contest.community_seat
      seat ? "#{office}, #{seat.name}" : office
    end

    # A candidate's share of the votes counted in their contest.
    def contest_share(contest, candidacy)
      total = contest.total_votes
      return unless candidacy.votes && total.positive?

      number_with_precision(candidacy.votes * 100.0 / total, precision: 2)
    end
  end
end
