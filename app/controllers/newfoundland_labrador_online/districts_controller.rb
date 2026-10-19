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
    end

    def show
      @district = NewfoundlandLabradorOnline::ProvincialElectoralDistrict.friendly.find(params[:id])
      authorize @district
      @versions = @district.versions.chronological
      @identifiers = @district.identifiers.order(:scheme)
      @settlements = settlements_inside(@district)
    end

    private

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
