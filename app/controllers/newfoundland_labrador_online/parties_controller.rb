# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Public pages for political parties: an index with current seats, and a page per party listing its current and
  # past members with their districts.
  class PartiesController < ApplicationController
    helper NewfoundlandLabradorOnline::DistrictsHelper
    helper NewfoundlandLabradorOnline::PartiesHelper

    PERSON_PRELOAD = [:string_translations, :slugs, { party_memberships: :political_party }].freeze

    def index
      authorize NewfoundlandLabradorOnline::PoliticalParty
      @parties = policy_scope(NewfoundlandLabradorOnline::PoliticalParty).with_attached_logo
                                                                         .order(:jurisdiction, :name).to_a
      @seats = current_seats
      @parties.sort_by! { |party| [-@seats.fetch(party.id, 0), party.name] }
    end

    def show
      @party = NewfoundlandLabradorOnline::PoliticalParty.with_attached_logo
                                                         .find_by!(jurisdiction: params[:jurisdiction],
                                                                   identifier: params[:id])
      authorize @party
      load_members(@party)
    end

    private

    # Sitting members per party id, resolved by dated membership so floor crossers count for their new party.
    def current_seats
      terms = NewfoundlandLabradorOnline::ElectedTerm.current.includes(:political_party, person: PERSON_PRELOAD)
      terms.to_a.group_by { |term| term.party_on&.id }.transform_values(&:size)
    end

    def load_members(party)
      @memberships = party.memberships.includes(person: PERSON_PRELOAD).order(started_on: :desc).to_a
      @terms_by_person = terms_for(@memberships.map(&:person_id))
      @current, @former = @memberships.partition { |m| m.ended_on.nil? && sitting?(m) }
    end

    def sitting?(membership)
      @terms_by_person[membership.person_id]&.any? { |term| term.ended_on.nil? }
    end

    def terms_for(person_ids)
      NewfoundlandLabradorOnline::ElectedTerm.where(person_id: person_ids)
                                             .includes(:election, region: %i[string_translations slugs])
                                             .latest_first.group_by(&:person_id)
    end
  end
end
