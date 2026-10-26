# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Public state pages (under /g like settlements): a list and a page per state linking to the districts, parties and
  # elections scoped to it. /g/provinces serves the states that identify as provinces; /g/states serves any state.
  class StatesController < ApplicationController
    helper NewfoundlandLabradorOnline::ProvincesHelper
    helper NewfoundlandLabradorOnline::DistrictsHelper
    helper NewfoundlandLabradorOnline::PartiesHelper
    helper NewfoundlandLabradorOnline::ElectionsHelper

    def index
      authorize BetterTogether::Geography::State
      @states = policy_scope(BetterTogether::Geography::State).with_translations.to_a
      @states.select!(&:province?) if params[:provinces]
    end

    def show
      @state = NewfoundlandLabradorOnline::Province.find_state(params[:id])
      authorize @state
      raise ActiveRecord::RecordNotFound if params[:provinces] && !@state.province?

      load_scoped_data
    end

    private

    def load_scoped_data
      load_province_data if @state.province?
      @regions = other_regions.with_translations.includes(:slugs).order(:identifier).to_a
      @settlements = @state.settlements.with_translations.includes(:slugs).order(:identifier).to_a
    end

    # Districts with their sitting members, parties with seat counts, elections with seats per party.
    def load_province_data
      load_districts
      @parties = @state.political_parties.ever_seated.with_attached_logo.includes(:state).order(:name).to_a
      @seats = NewfoundlandLabradorOnline::Civic::Roster.current_seats_by_party_id
      @elections = @state.elections.includes(:state).latest_first.to_a
      @seat_counts = NewfoundlandLabradorOnline::Civic::Roster.seats_by_election_and_party(@elections.map(&:id))
    end

    def load_districts
      @districts = @state.provincial_electoral_districts.with_translations.includes(:slugs).with_attached_cover_image
                         .order(:identifier).to_a
      @current_terms = NewfoundlandLabradorOnline::Civic::Roster.current_holdings(region_ids: @districts.map(&:id))
                                                                .index_by(&:region_id)
      prefetch_mention_visibility(@current_terms.values.map(&:person))
    end

    def other_regions
      @state.regions.where.not(type: 'NewfoundlandLabradorOnline::ProvincialElectoralDistrict')
    end
  end
end
