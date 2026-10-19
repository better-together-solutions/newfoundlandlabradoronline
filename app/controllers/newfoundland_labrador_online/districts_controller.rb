# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Public pages for provincial electoral districts: an index of all districts and a page per district with its
  # current boundary, history of names and boundaries, external identifiers and the settlements inside.
  class DistrictsController < ApplicationController
    helper NewfoundlandLabradorOnline::DistrictsHelper

    def index
      authorize NewfoundlandLabradorOnline::ProvincialElectoralDistrict
      @districts = policy_scope(NewfoundlandLabradorOnline::ProvincialElectoralDistrict).with_translations
                                                                                        .order(:identifier)
      load_current_members(@districts)
    end

    def show
      @district = NewfoundlandLabradorOnline::ProvincialElectoralDistrict.friendly.find(params[:id])
      authorize @district
      @versions = @district.versions.chronological
      @identifiers = @district.identifiers.order(:scheme)
      @settlements = settlements_inside(@district)
      load_electoral_history(@district)
    end

    private

    # Named parties come before independents and unaffiliated seats unless the latter hold more seats.
    def seat_rank(party)
      return 2 unless party

      party.identifier == 'independent' ? 1 : 0
    end

    # Each district's sitting member (by region id) and the seats per party for the legend.
    def load_current_members(districts)
      @current_terms = NewfoundlandLabradorOnline::ElectedTerm.current.where(region_id: districts.map(&:id))
                                                              .includes(:person, :political_party).index_by(&:region_id)
      counts = @current_terms.values.group_by(&:party_on).transform_values(&:size)
      @seats = counts.sort_by { |party, count| [-count, seat_rank(party), party&.short_name.to_s] }
    end

    def load_electoral_history(district)
      @terms = district.elected_terms.includes(:person, :election).latest_first
      @contests = district.contests.includes(:election, :candidacies).sort_by { |c| c.election.held_on }.reverse
    end

    def settlements_inside(district)
      version = district.current_version
      return BetterTogether::Geography::Settlement.none unless version

      point = 'ST_SetSRID(ST_MakePoint(better_together_geography_spaces.longitude, ' \
              'better_together_geography_spaces.latitude), 4326)::geography'
      inside = "ST_Covers((SELECT boundary FROM region_versions WHERE id = ?), #{point})"
      BetterTogether::Geography::Settlement.joins(:space).with_translations.order(:identifier).where(inside, version.id)
    end
  end
end
