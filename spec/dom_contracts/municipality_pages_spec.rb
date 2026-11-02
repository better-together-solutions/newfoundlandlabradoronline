# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/ExampleLength
# Stable identifiers for the municipality, municipal election and settlement card pages, loaded from the real packets.
RSpec.describe 'Municipality pages', type: :request do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:province) { BetterTogether::Geography::State.find_by!(iso_code: 'CA-NL') }

  before do
    configure_host_platform
    { 'corner-brook' => 'Corner Brook', 'st-john-s' => "St. John's" }.each do |identifier, name|
      create(:geography_settlement, identifier:, name:, state: province)
    end
    NewfoundlandLabradorOnline::Civic::MunicipalRosterLoader.new(apply: true).call
    NewfoundlandLabradorOnline::Civic::MunicipalElectionLoader.new(apply: true).call
  end

  it 'lists municipalities with a council', :aggregate_failures do
    get "/#{locale}/e/municipalities/nl"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="municipalities-index"', 'id="municipalities-list"',
                                     'id="municipality-corner-brook"', 'id="municipality-st-john-s"')
  end

  it 'shows a municipality with its leaders, council and latest election', :aggregate_failures do
    get "/#{locale}/e/municipalities/nl/st-john-s"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="municipality-page"', 'id="municipality-name"', 'id="municipality-status"',
                                     'id="municipality-facts"', 'id="council-mayor"', 'id="council-deputy-mayor"',
                                     'id="council-members"', 'id="council-source"', 'id="municipality-election"',
                                     'id="municipality-election-link"')
    expect(response.body).to include('Danny Breen', 'Ron Ellsworth', 'Ward 5', '15,216', '56.74%')
  end

  it 'draws the ward map between leaders and councillors once boundaries are loaded', :aggregate_failures do
    get "/#{locale}/e/municipalities/nl/st-john-s"
    expect(response.body).not_to include('id="municipality-ward-map"')

    NewfoundlandLabradorOnline::Civic::WardBoundaryLoader.new(apply: true).call
    get "/#{locale}/e/municipalities/nl/st-john-s"

    body = response.body
    expect(body).to include('id="municipality-ward-map"', 'id="ward-map-source"', 'City of St. John&#39;s',
                            'https://map.stjohns.ca/mapsrv/rest/services/Mapcentre/Administrative_Boundaries/MapServer')
    expect(body.index('id="municipality-leaders"')).to be < body.index('id="municipality-ward-map"')
    expect(body.index('id="municipality-ward-map"')).to be < body.index('id="council-members"')
    expect(body.scan('data-party-overlay-overlays-value').size).to eq(1)
  end

  it 'shows every contest of a municipal election, marking acclamations', :aggregate_failures do
    get "/#{locale}/e/elections/municipal/nl/st-john-s/2025"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="municipal-election-page"', 'id="election-date"', 'id="election-source"')
    expect(response.body).to include('Ward 1', 'Acclaimed', 'Kate Cadigan', '16,577')
    expect(response.body.scan('id="newfoundland_labrador_online_electoral_contest_').size).to eq(8)
  end

  it 'links a settlement page to its municipality and is a 404 for places without a council', :aggregate_failures do
    get "/#{locale}/g/settlements/corner-brook"
    expect(response.body).to include('id="settlement-municipal-card"', 'id="settlement-municipal-link"')

    create(:geography_settlement, identifier: 'nowhere', name: 'Nowhere', state: province)
    get "/#{locale}/e/municipalities/nl/nowhere"
    expect(response).to have_http_status(:not_found)
  end

  it 'does not list municipal elections with provincial ones', :aggregate_failures do
    get "/#{locale}/e/elections"

    expect(response.body).not_to include('municipal')
    expect(response.body).not_to include('Breen')
  end
end
# rubocop:enable RSpec/ExampleLength
