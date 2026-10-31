# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Settlement page host hooks' do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:settlement) { create(:geography_settlement, identifier: 'hooked-town', name: 'Hookedtown') }
  let(:body) { response.body }

  before { configure_host_platform }

  context 'when the settlement has a map space' do
    before do
      space = BetterTogether::Geography::Space.create!(latitude: 48.95, longitude: -57.95)
      BetterTogether::Geography::GeospatialSpace.create!(geospatial: settlement, space:)
      get "/#{locale}/g/settlements/#{settlement.slug}"
    end

    it 'puts the map above the tabs' do
      expect(body.index('id="settlement-map"')).to be < body.index('id="settlement-tabbed-section"')
    end

    it 'keeps the Posts and Events tabs from CE' do
      expect(body).to include('id="posts-tab"', 'id="events-tab"')
    end
  end

  context 'when the settlement has a stored boundary' do
    let(:polygon) do
      RGeo::Geographic.spherical_factory(srid: 4326)
                      .parse_wkt('MULTIPOLYGON(((-58 48.9,-58 49,-57.9 49,-57.9 48.9,-58 48.9)))')
    end
    let(:space) { BetterTogether::Geography::Space.create!(latitude: 48.95, longitude: -57.95, boundary: polygon) }

    before do
      BetterTogether::Geography::GeospatialSpace.create!(geospatial: settlement, space:)
    end

    it 'credits the boundary source in one link under the map', :aggregate_failures do
      space.update!(metadata: { 'boundary_source' => { 'osm_type' => 'relation', 'osm_id' => 1234 } })
      get "/#{locale}/g/settlements/#{settlement.slug}"

      credit = Nokogiri::HTML(body).at_css('#settlement-boundary-credit')
      expect(credit.text.squish).to eq('Boundary: OpenStreetMap (ODbL)')
      expect(credit.css('a').map { |a| a['href'] }).to eq(['https://www.openstreetmap.org/relation/1234'])
    end

    it 'credits nothing when the source is not recorded' do
      get "/#{locale}/g/settlements/#{settlement.slug}"

      expect(body).not_to include('settlement-boundary-credit')
    end
  end
end
