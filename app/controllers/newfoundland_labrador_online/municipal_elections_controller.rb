# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # One municipal general election: every contest for a council on one date.
  class MunicipalElectionsController < ApplicationController
    include NewfoundlandLabradorOnline::ProvinceScoped

    helper NewfoundlandLabradorOnline::MunicipalitiesHelper
    helper NewfoundlandLabradorOnline::PartiesHelper

    def show
      @municipality = find_municipality
      authorize :municipality, policy_class: NewfoundlandLabradorOnline::MunicipalityPolicy
      @election = @municipality.elections.find { |election| election.year == params[:year].to_i }
      raise ActiveRecord::RecordNotFound unless @election

      @contests = sorted_contests(@election)
      prefetch_mention_visibility(@contests.flat_map { |contest| contest.candidacies.map(&:member) })
    end

    ORDER = %w[mayor deputy_mayor councillor member].freeze

    private

    def find_municipality
      settlement = BetterTogether::Geography::Settlement.friendly.find(params[:settlement])
      municipality = NewfoundlandLabradorOnline::Civic::Municipality.for(settlement)
      raise ActiveRecord::RecordNotFound unless municipality && settlement.state_id == @province.id

      municipality
    end

    def sorted_contests(election)
      election.contests.sort_by { |c| [ORDER.index(c.office), c.community_seat&.position || 999] }
    end
  end
end
