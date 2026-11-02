# frozen_string_literal: true

require 'rails_helper'

# Pins sit on top of coloured areas, so a listing drawn as areas shows none unless asked.
RSpec.describe NewfoundlandLabradorOnline::ListingMapHelper, type: :helper do
  include RequestSpecHelper

  before { configure_host_platform }

  let(:place) { BetterTogether::Geography::Space.create!(latitude: 48.95, longitude: -57.95) }
  let(:settlement) do
    create(:geography_settlement, identifier: 'pin-town', name: 'Pintown').tap do |record|
      BetterTogether::Geography::GeospatialSpace.create!(geospatial: record, space: place)
    end
  end
  let(:area) { ->(_record) { { color: '#336699', popup: 'Pintown' } } }

  def points(**)
    helper.listing_map([settlement], kind: 'pins', url_for: ->(_record) { '/x' }, **).leaflet_points
  end

  it 'draws a pin per record by default' do
    expect(points.size).to eq(1)
  end

  it 'draws none when the records are drawn as areas' do
    expect(points(overlay_for: area)).to eq([])
  end

  it 'draws pins over areas when asked' do
    expect(points(overlay_for: area, pins: true).size).to eq(1)
  end

  it 'hides pins on any listing when asked' do
    expect(points(pins: false)).to eq([])
  end
end
