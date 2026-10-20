# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Public pages for provincial electoral districts: an index of all districts and a page per district with its
  # current boundary, history of names and boundaries, external identifiers and the settlements inside.
  class DistrictsController < ApplicationController
    include NewfoundlandLabradorOnline::ProvinceScoped

    helper NewfoundlandLabradorOnline::DistrictsHelper
    helper NewfoundlandLabradorOnline::PartiesHelper
    helper NewfoundlandLabradorOnline::ElectionsHelper

    PERSON_PRELOAD = [:string_translations, { party_memberships: :political_party }].freeze

    def index
      authorize NewfoundlandLabradorOnline::ProvincialElectoralDistrict
      @districts = province_districts.with_translations.with_attached_cover_image.order(:identifier).to_a
      preload_versions(@districts)
      load_current_members(@districts)
    end

    def show
      @district = province_districts.includes(:state).friendly.find(params[:id])
      authorize @district
      @versions = @district.versions.without_boundary.chronological
      @identifiers = @district.identifiers.order(:scheme)
      @settlements = settlements_inside(@district)
      load_electoral_history(@district)
    end

    private

    def province_districts
      districts = policy_scope(NewfoundlandLabradorOnline::ProvincialElectoralDistrict)
      @province ? districts.where(state: @province) : districts
    end

    # Named parties come before independents and unaffiliated seats unless the latter hold more seats.
    def seat_rank(party)
      return 2 unless party

      party.identifier == 'independent' ? 1 : 0
    end

    # Versions without their boundaries, so popups can read dates and area without loading full-resolution geometry.
    def preload_versions(districts)
      by_region = NewfoundlandLabradorOnline::RegionVersion.without_boundary.where(region_id: districts.map(&:id))
                                                           .group_by(&:region_id)
      districts.each { |district| district.association(:versions).target = by_region.fetch(district.id, []) }
    end

    # Each district's sitting member (by region id) and the seats per party for the legend.
    def load_current_members(districts)
      @current_terms = NewfoundlandLabradorOnline::ElectedTerm.current.where(region_id: districts.map(&:id))
                                                              .includes(:political_party, person: PERSON_PRELOAD)
                                                              .index_by(&:region_id)
      counts = @current_terms.values.group_by(&:party_on).transform_values(&:size)
      @seats = counts.sort_by { |party, count| [-count, seat_rank(party), party&.short_name.to_s] }
    end

    def load_electoral_history(district)
      @terms = district.elected_terms.includes(:election, :political_party, person: PERSON_PRELOAD).latest_first
      contests = district.contests.includes(:election, candidacies: :political_party)
      @contests = contests.sort_by { |contest| contest.election.held_on }.reverse
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
