# frozen_string_literal: true

require 'rails_helper'

# The settlement map must show the whole boundary, even when the settlement pin is the only point on it.
RSpec.describe 'Settlement map fit', :js, type: :feature do
  include RequestSpecHelper

  let(:polygon) do
    RGeo::Geographic.spherical_factory(srid: 4326)
                    .parse_wkt('MULTIPOLYGON(((-58.4 48.7,-58.4 49.2,-57.5 49.2,-57.5 48.7,-58.4 48.7)))')
  end
  let(:visible) do
    <<~JS
      (() => {
        const map = window.Stimulus.getControllerForElementAndIdentifier(
          document.querySelector('#settlement-map [data-controller]'), 'better_together--map').map
        const b = map.getBounds()
        return [b.getSouth(), b.getWest(), b.getNorth(), b.getEast()]
      })()
    JS
  end

  before do
    configure_host_platform.update!(privacy: 'public')
    settlement = create(:geography_settlement, identifier: 'wide-town', name: 'Widetown')
    space = BetterTogether::Geography::Space.create!(latitude: 48.95, longitude: -57.95, boundary: polygon)
    BetterTogether::Geography::GeospatialSpace.create!(geospatial: settlement, space:)
  end

  it 'frames the whole boundary' do
    visit "/#{I18n.default_locale}/g/settlements/wide-town"
    page.has_css?('#settlement-map .leaflet-interactive', wait: 15)
    south, west, north, east = page.evaluate_script(visible)

    expect([south <= 48.7, west <= -58.4, north >= 49.2, east >= -57.5]).to eq([true] * 4)
  end
end
