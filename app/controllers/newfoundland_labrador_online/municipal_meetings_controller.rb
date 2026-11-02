# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # The council's meetings for one municipality: a timeline with a filter per kind of meeting.
  class MunicipalMeetingsController < ApplicationController
    include NewfoundlandLabradorOnline::ProvinceScoped

    helper NewfoundlandLabradorOnline::MunicipalitiesHelper

    def index
      settlement = BetterTogether::Geography::Settlement.friendly.find(params[:id])
      @municipality = NewfoundlandLabradorOnline::Civic::Municipality.for(settlement)
      raise ActiveRecord::RecordNotFound unless @municipality && settlement.state_id == @province.id

      authorize :municipality, :show?, policy_class: NewfoundlandLabradorOnline::MunicipalityPolicy
      @meetings = council_meetings
      @categories = @meetings.filter_map(&:category).uniq.sort_by { |category| category.name.to_s }
    end

    private

    # Events, their slugs and categories are preloaded so the query count stays flat as meetings are added.
    def council_meetings
      Meeting.where(body: @municipality.council).newest_first
             .includes(:documents, event: [:string_translations, { categories: :string_translations }]).to_a
    end
  end
end
