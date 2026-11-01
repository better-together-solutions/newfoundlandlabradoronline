# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Links and labels for the municipality pages.
  module MunicipalitiesHelper
    WARD_COLORS = %w[#e07b39 #3b8ea5 #7a9e3f #a259a2 #c9a227].freeze

    def ward_map(municipality)
      identifier = "wards-#{municipality.settlement.identifier}"
      NewfoundlandLabradorOnline::WardMap.find_or_initialize_by(identifier:)
                                         .tap { |map| map.seat_boundaries = municipality.ward_boundaries }
    end

    # One coloured, clickable area per ward: the ward name and who sits for it.
    def ward_overlays(municipality, located_map)
      holders = municipality.councillors.select(&:seat).group_by { |office| office.seat.id }
      municipality.ward_boundaries.each_with_index.filter_map do |boundary, index|
        geometry = located_map.geometries[boundary.id]
        geometry && ward_overlay(boundary.community_seat, geometry, index, holders)
      end
    end

    def ward_overlay(seat, geometry, index, holders)
      names = Array(holders[seat.id]).map { |office| office.person.name }
      { geometry:, color: WARD_COLORS[index % WARD_COLORS.size], popup: ward_popup(seat.name, names) }
    end

    def ward_popup(ward, names)
      safe_join([tag.strong(ward), names.join(', ').presence].compact, tag.br).to_str
    end

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
