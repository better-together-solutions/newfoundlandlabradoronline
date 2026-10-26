# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Public pages for political parties: an index with current seats, and a page per party listing its current and
  # past members with their districts.
  class PartiesController < ApplicationController
    include NewfoundlandLabradorOnline::ProvinceScoped

    helper NewfoundlandLabradorOnline::DistrictsHelper
    helper NewfoundlandLabradorOnline::PartiesHelper

    def index
      authorize NewfoundlandLabradorOnline::PoliticalParty
      @scope = params[:jurisdiction]
      @parties = scoped_parties.ever_seated.with_attached_logo.includes(:state).order(:jurisdiction, :name).to_a
      @seats = current_seats
      @parties.sort_by! { |party| [-@seats.fetch(party.id, 0), party.name] }
    end

    def show
      @party = scoped_parties.with_attached_logo.includes(:state).find_by!(identifier: params[:id])
      authorize @party
      load_members(@party)
    end

    private

    def scoped_parties
      parties = policy_scope(NewfoundlandLabradorOnline::PoliticalParty)
      parties = parties.where(jurisdiction: params[:jurisdiction]) if params[:jurisdiction]
      @province ? parties.where(state: @province) : parties
    end

    # Sitting members per party id, resolved by dated membership so floor crossers count for their new party.
    def current_seats
      NewfoundlandLabradorOnline::Civic::Roster.current_seats_by_party_id
    end

    def load_members(party)
      roster = NewfoundlandLabradorOnline::Civic::Roster
      @memberships = roster.party_holdings(party)
      @terms_by_person = roster.holdings_by_person(@memberships.map(&:person_id).uniq)
      @current, @former = @memberships.partition { |m| m.ended_on.nil? && sitting?(m) }
      prefetch_mention_visibility(@memberships.map(&:person))
    end

    def sitting?(membership)
      @terms_by_person[membership.person_id]&.any?(&:current?)
    end
  end
end
