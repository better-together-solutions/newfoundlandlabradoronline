# frozen_string_literal: true

require 'rails_helper'

# Stable identifiers that the district page documentation screenshots and downstream tooling target.
RSpec.describe 'Electoral district page DOM contract', type: :request do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:path) { Rails.root.join('spec/fixtures/nl_regions/two_districts.geojson') }
  let(:page_ids) do
    %w[district-page district-name district-kind district-map-section district-facts district-area
       district-since district-authority district-licence district-settlements district-history
       district-identifiers district-member district-members district-results district-member-party]
  end

  before do
    configure_host_platform
    NewfoundlandLabradorOnline::Geography::ProvincialDistrictLoader.new(path:).call
  end

  def load_elections
    NewfoundlandLabradorOnline::Geography::ProvincialElectionLoader.new(
      path: Rails.root.join('spec/fixtures/nl_regions/two_elections.json')
    ).call
  end

  def place_settlement(settlement)
    space = BetterTogether::Geography::Space.create!(latitude: 48.95, longitude: -57.95)
    BetterTogether::Geography::GeospatialSpace.create!(geospatial: settlement, space:)
  end

  def attach_generated_cover(name)
    district = NewfoundlandLabradorOnline::ProvincialElectoralDistrict.find_by!(identifier: "nl-ped-#{name}")
    jpeg = Vips::Image.black(40, 24).write_to_buffer('.jpg')
    NewfoundlandLabradorOnline::Geography::DistrictCover.call(region: district, io: StringIO.new(jpeg),
                                                              filename: "nl-ped-#{name}.jpg")
  end

  # rubocop:disable-next RSpec/ExampleLength
  it 'keeps the generated map off the page while the interactive map shows, but on the card', :aggregate_failures do
    attach_generated_cover('corner-brook')

    get "/#{locale}/e/districts/provincial/nl/nl-ped-corner-brook"
    expect(response.body).to include('id="district-map-section"')
    expect(response.body).not_to include('id="district-cover"')

    get "/#{locale}/e/districts/provincial/nl"
    expect(response.body).to match(%r{<img[^>]*card-img-top[^>]*alt="Corner Brook"[^>]*rails/active_storage})
  end

  it 'shows an uploaded cover above the title', :aggregate_failures do
    district = NewfoundlandLabradorOnline::ProvincialElectoralDistrict.find_by!(identifier: 'nl-ped-corner-brook')
    jpeg = Vips::Image.black(40, 24).write_to_buffer('.jpg')
    district.cover_image.attach(io: StringIO.new(jpeg), filename: 'custom.jpg', content_type: 'image/jpeg')

    get "/#{locale}/e/districts/provincial/nl/nl-ped-corner-brook"
    expect(response.body).to include('id="district-cover"', 'cover-image')
  end

  it 'has no cover area without a cover, and cards fall back to the default image', :aggregate_failures do
    get "/#{locale}/e/districts/provincial/nl/nl-ped-corner-brook"
    expect(response.body).not_to include('id="district-cover"')

    get "/#{locale}/e/districts/provincial/nl"
    expect(response.body).to include('card-img-top')
  end

  it 'exposes the index identifiers', :aggregate_failures do
    get "/#{locale}/e/districts/provincial/nl"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="districts-index"', 'id="districts-list"', 'id="listing-map-section"')
    expect(response.body).to include('id="newfoundland_labrador_online_provincial_electoral_district_')
  end

  context 'with the listing map' do
    let(:points) do
      get "/#{locale}/e/districts/provincial/nl"
      JSON.parse(CGI.unescapeHTML(response.body[/data-better_together--map-spaces-value="([^"]*)"/, 1]))
    end
    let(:popup) { points.first['popup_html'] }

    it 'has a pin per district' do
      expect(points.size).to eq(2)
    end

    it 'titles and describes each pin in its popup' do
      expect(popup).to include('<h3', '/e/districts/provincial/nl/nl-ped-corner-brook', 'km²',
                               'Provincial electoral district')
    end

    it 'draws the outlines' do
      points
      expect(response.body).to include('data-party-overlay-overlays-value')
    end
  end

  context 'with party colours' do
    before do
      NewfoundlandLabradorOnline::Geography::PoliticalPartyLoader.new.call
      load_elections
      get "/#{locale}/e/districts/provincial/nl"
    end

    it 'colours each district area and lists the parties in a legend', :aggregate_failures do
      expect(response.body).to include('id="districts-party-legend"', 'data-party-overlay-overlays-value')
      expect(response.body).to include('id="legend_newfoundland_labrador_online_political_party_')
    end

    it 'uses the sitting member party colour for the area' do
      liberal = NewfoundlandLabradorOnline::PoliticalParty.find_by!(identifier: 'liberal')

      expect(CGI.unescapeHTML(response.body)).to include(%("color":"#{liberal.display_color}"))
    end
  end

  it 'exposes the district page identifiers', :aggregate_failures do
    NewfoundlandLabradorOnline::Geography::PoliticalPartyLoader.new.call
    load_elections
    get "/#{locale}/e/districts/provincial/nl/nl-ped-corner-brook"

    expect(response).to have_http_status(:ok)
    page_ids.each { |id| expect(response.body).to include(%(id="#{id}")) }
  end

  context 'with the boundary data credit' do
    def layer_keys
      raw = response.body[/data-better_together--map-layers-value="([^"]*)"/, 1]
      raw && JSON.parse(CGI.unescapeHTML(raw)).pluck('key')
    end

    it 'credits the boundary authority on the district map', :aggregate_failures do
      get "/#{locale}/e/districts/provincial/nl/nl-ped-corner-brook"

      expect(layer_keys).to eq(['nl_electoral_boundaries'])
      expect(CGI.unescapeHTML(response.body)).to include('Electoral Boundaries Commission')
    end

    it 'credits it on the districts listing map' do
      get "/#{locale}/e/districts/provincial/nl"

      expect(layer_keys).to eq(['nl_electoral_boundaries'])
    end
  end

  it 'draws the current boundary on the map' do
    get "/#{locale}/e/districts/provincial/nl/nl-ped-corner-brook"

    expect(response.body).to include('data-party-overlay-overlays-value')
  end

  it 'lists settlements whose point falls inside the boundary' do
    place_settlement(create(:geography_settlement, identifier: 'in-district', name: 'Insideville'))
    get "/#{locale}/e/districts/provincial/nl/nl-ped-corner-brook"

    expect(response.body).to include('Insideville')
  end

  it 'answers 404 for an unknown district' do
    get "/#{locale}/e/districts/provincial/nl/nl-ped-nowhere"

    expect(response).to have_http_status(:not_found)
  end
end
