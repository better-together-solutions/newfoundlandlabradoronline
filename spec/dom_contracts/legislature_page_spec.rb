# frozen_string_literal: true

require 'rails_helper'

# Stable identifiers for the legislature page and its link from the province page.
RSpec.describe 'Legislature page', type: :request do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:fixtures) { Rails.root.join('spec/fixtures/nl_regions') }

  before do
    configure_host_platform
    geography = NewfoundlandLabradorOnline::Geography
    geography::ProvincialDistrictLoader.new(path: fixtures.join('two_districts.geojson')).call
    geography::PoliticalPartyLoader.new.call
    geography::ProvincialElectionLoader.new(path: fixtures.join('two_elections.json')).call
  end

  it 'lists sitting members by district with party seat counts', :aggregate_failures do
    get "/#{locale}/e/members/provincial/nl"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="legislature-page"', 'id="legislature-name"', 'id="legislature-seats"',
                                     'id="legislature-members"', 'id="legislature-former"')
    expect(response.body).to include('Jim Parsons', "/#{locale}/e/districts/provincial/nl/nl-ped-corner-brook")
  end

  it 'lists former members apart from sitting ones' do
    get "/#{locale}/e/members/provincial/nl"

    former = response.body[/id="legislature-former".*/m]
    expect(former).to include('Gerry Byrne')
  end

  it 'is linked from the province page' do
    get "/#{locale}/g/provinces/nl"

    expect(response.body).to include('id="province-legislature-link"')
  end

  it 'is not found for a province without a legislature' do
    get "/#{locale}/e/members/provincial/on"

    expect(response).to have_http_status(:not_found)
  end
end
