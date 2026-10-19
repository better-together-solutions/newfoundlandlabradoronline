# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Public pages for general elections: an index with seat totals, and a page per election with every contest.
  class ElectionsController < ApplicationController
    helper NewfoundlandLabradorOnline::DistrictsHelper
    helper NewfoundlandLabradorOnline::PartiesHelper
    helper NewfoundlandLabradorOnline::ElectionsHelper

    def index
      authorize NewfoundlandLabradorOnline::Election
      @elections = policy_scope(NewfoundlandLabradorOnline::Election).latest_first.to_a
      @seat_counts = NewfoundlandLabradorOnline::ElectedTerm.where(election_id: @elections.map(&:id))
                                                            .group(:election_id, :party_name).count
    end

    def show
      @election = find_election
      authorize @election
      @contests = @election.contests.includes(:candidacies, region: %i[string_translations slugs]).to_a
                           .sort_by { |contest| contest.region.name }
      @parties = parties_in(@contests)
    end

    private

    def find_election
      NewfoundlandLabradorOnline::Election.where(jurisdiction: params[:jurisdiction])
                                          .find_by!('EXTRACT(YEAR FROM held_on) = ?', params[:year])
    end

    def parties_in(contests)
      ids = contests.flat_map { |contest| contest.candidacies.map(&:political_party_id) }.compact.uniq
      NewfoundlandLabradorOnline::PoliticalParty.where(id: ids).index_by(&:id)
    end
  end
end
