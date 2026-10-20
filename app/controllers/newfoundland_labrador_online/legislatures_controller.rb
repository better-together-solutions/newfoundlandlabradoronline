# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # The members of a province's legislature: sitting members by district with their party, and former members.
  class LegislaturesController < ApplicationController
    include NewfoundlandLabradorOnline::ProvinceScoped

    helper NewfoundlandLabradorOnline::DistrictsHelper
    helper NewfoundlandLabradorOnline::PartiesHelper

    def show
      @legislature = NewfoundlandLabradorOnline::Civic::Provisioner.new.legislature_for(@province)
      raise ActiveRecord::RecordNotFound unless @legislature

      authorize @legislature, :show?, policy_class: BetterTogether::CommunityPolicy
      roster = NewfoundlandLabradorOnline::Civic::Roster
      @members = roster.legislature_holdings(@legislature)
      @former = roster.legislature_holdings(@legislature, current: false)
      counts = @members.group_by(&:party_on).transform_values(&:size)
      @seats = counts.sort_by { |party, n| [-n, party&.short_name.to_s] }
    end
  end
end
