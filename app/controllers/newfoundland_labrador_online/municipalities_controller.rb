# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Public pages for municipal government: a listing of municipalities with a council, and a page per municipality
  # with its status, council and elections.
  class MunicipalitiesController < ApplicationController
    include NewfoundlandLabradorOnline::ProvinceScoped

    helper NewfoundlandLabradorOnline::MunicipalitiesHelper
    helper NewfoundlandLabradorOnline::PartiesHelper

    def index
      authorize :municipality, policy_class: NewfoundlandLabradorOnline::MunicipalityPolicy
      listed = NewfoundlandLabradorOnline::Civic::Municipality.listed
      listed = listed.select { |municipality| municipality.settlement.state_id == @province.id } if @province
      @municipalities = listed.sort_by { |municipality| municipality.settlement.name }
    end

    def show
      settlement = BetterTogether::Geography::Settlement.friendly.find(params[:id])
      @municipality = NewfoundlandLabradorOnline::Civic::Municipality.for(settlement)
      raise ActiveRecord::RecordNotFound unless @municipality && settlement.state_id == @province.id

      authorize :municipality, policy_class: NewfoundlandLabradorOnline::MunicipalityPolicy
      prefetch_mention_visibility(@municipality.offices.map(&:person))
    end
  end
end
