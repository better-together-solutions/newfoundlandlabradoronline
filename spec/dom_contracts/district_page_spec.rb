# frozen_string_literal: true

require 'rails_helper'

# Stable identifiers that the district page documentation screenshots and downstream tooling target.
RSpec.describe 'Electoral district page DOM contract', type: :request do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:path) { Rails.root.join('spec/fixtures/nl_regions/two_districts.geojson') }

  before do
    configure_host_platform
    NewfoundlandLabradorOnline::Geography::ProvincialDistrictLoader.new(path:).call
  end

  def place_settlement(settlement)
    space = BetterTogether::Geography::Space.create!(latitude: 48.95, longitude: -57.95)
    BetterTogether::Geography::GeospatialSpace.create!(geospatial: settlement, space:)
  end

  it 'exposes the index identifiers', :aggregate_failures do
    get "/#{locale}/districts"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="districts-index"', 'id="districts-list"')
    expect(response.body).to include('id="row_newfoundland_labrador_online_provincial_electoral_district_')
  end

  it 'exposes the district page identifiers', :aggregate_failures do
    get "/#{locale}/districts/nl-ped-corner-brook"

    ids = %w[district-page district-name district-kind district-map-section district-facts district-area district-since
             district-authority district-licence district-settlements district-history district-identifiers]
    expect(response).to have_http_status(:ok)
    ids.each { |id| expect(response.body).to include(%(id="#{id}")) }
  end

  it 'draws the current boundary on the map' do
    get "/#{locale}/districts/nl-ped-corner-brook"

    expect(response.body).to include('data-better_together--map-boundary-value')
  end

  it 'lists settlements whose point falls inside the boundary' do
    place_settlement(create(:geography_settlement, identifier: 'in-district', name: 'Insideville'))
    get "/#{locale}/districts/nl-ped-corner-brook"

    expect(response.body).to include('Insideville')
  end

  it 'answers 404 for an unknown district' do
    get "/#{locale}/districts/nl-ped-nowhere"

    expect(response).to have_http_status(:not_found)
  end
end
