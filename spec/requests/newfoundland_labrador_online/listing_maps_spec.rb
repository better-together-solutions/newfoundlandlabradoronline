# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Geospatial listing maps' do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:place) { BetterTogether::Geography::Space.create!(latitude: 48.95, longitude: -57.95) }

  before do
    configure_host_platform
    settlement = create(:geography_settlement, identifier: 'mapped-town', name: 'Mappedtown')
    BetterTogether::Geography::GeospatialSpace.create!(geospatial: settlement, space: place)
  end

  context 'when listing settlements' do
    let(:body) { response.body }

    before { get "/#{locale}/g/settlements" }

    it 'puts the map between the heading and the list' do
      map_at = body.index('id="listing-map-section"')

      expect([body.index('<h1') < map_at, map_at < body.index('<table')]).to eq([true, true])
    end

    it 'adds a pin for each settlement with coordinates' do
      expect(CGI.unescapeHTML(body)).to include('Mappedtown')
    end
  end
end
