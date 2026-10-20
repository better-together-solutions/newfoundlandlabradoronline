# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Public state pages (under /g like settlements): a list and a page per state linking to the districts, parties and
  # elections scoped to it. /g/provinces serves the states that identify as provinces; /g/states serves any state.
  class StatesController < ApplicationController
    helper NewfoundlandLabradorOnline::ProvincesHelper

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
      @districts = @state.provincial_electoral_districts.with_translations.order(:identifier)
      @parties = @state.political_parties.ever_seated.order(:name)
      @elections = @state.elections.latest_first
    end
  end
end
