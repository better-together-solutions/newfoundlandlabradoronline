# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::SettlementMap do
  include RequestSpecHelper

  let(:settlement) { create(:geography_settlement, identifier: 'map-town', name: 'Maptown') }
  let(:locations) { BetterTogether::Geography::LocatableLocation }
  let(:map) do
    described_class.new(settlement:).tap { |m| m.scope_for = lambda(&:all) }
  end

  before do
    configure_host_platform
    space = BetterTogether::Geography::Space.create!(latitude: 48.95, longitude: -57.95)
    BetterTogether::Geography::GeospatialSpace.create!(geospatial: settlement, space:)
    settlement.reload
  end

  def geocoded_address(latitude: 48.96, longitude: -57.94)
    create(:better_together_address).tap do |address|
      address.space.update!(latitude:, longitude:)
      locations.create!(locatable: address, location: settlement)
    end
  end

  def located_post(title, place)
    platform = BetterTogether::Platform.find_by(host: true)
    post = create(:better_together_post, platform:, privacy: 'public', published_at: 1.hour.ago, title:,
                                         author: BetterTogether::User.first.person)
    locations.create!(locatable: post, location: place)
    post
  end

  it 'is a locatable map subtype with the standard policy', :aggregate_failures do
    expect(described_class.superclass).to eq(BetterTogether::Geography::LocatableMap)
    expect(Pundit::PolicyFinder.new(map).policy).to eq(NewfoundlandLabradorOnline::SettlementMapPolicy)
  end

  it 'centres on the settlement pin' do
    expect(map.center_for_leaflet).to eq('48.95,-57.95')
  end

  it 'has the settlement pin as its first point, linking to the settlement', :aggregate_failures do
    pin = map.leaflet_points.first

    expect(pin).to include(lat: 48.95, lng: -57.95)
    expect(pin[:popup_html]).to include('Maptown', "/g/settlements/#{settlement.slug}")
  end

  it 'has no boundary until one is stored' do
    expect(map.boundary).to be_nil
  end

  it 'adds records located at a geocoded address inside the settlement, with their type styling', :aggregate_failures do
    post = located_post('Harbour news', geocoded_address)

    point = map.leaflet_points.last

    expect(point).to include(lat: 48.96, lng: -57.94, type: 'BetterTogether::Post', icon: 'fa-newspaper')
    expect(point[:popup_html]).to include('Harbour news', "/posts/#{post.slug}")
    expect(map.spaces.size).to eq(2)
  end

  it 'lists the types that have points, for the legend' do
    located_post('Harbour news', geocoded_address)

    expect(map.types.pluck(:key)).to eq(['BetterTogether::Post'])
  end

  it 'escapes names in popup markup', :aggregate_failures do
    located_post('<img src=x onerror=alert(1)>', geocoded_address)

    popup = map.leaflet_points.last[:popup_html]

    expect(popup).to include('&lt;img src=x onerror=alert(1)&gt;')
    expect(popup).not_to include('<img')
  end

  it 'leaves out records located at the settlement itself, which the pin already shows' do
    located_post('At the pin', settlement)

    expect(map.leaflet_points.size).to eq(1)
  end

  it 'maps only what the scope allows' do
    located_post('Harbour news', geocoded_address)
    map.scope_for = lambda(&:none)

    expect(map.leaflet_points.size).to eq(1)
  end

  it 'maps nothing but the pin without a scope' do
    located_post('Harbour news', geocoded_address)

    expect(described_class.new(settlement:).leaflet_points.size).to eq(1)
  end

  describe '#boundary_credit' do
    let(:polygon) do
      RGeo::Geographic.spherical_factory(srid: 4326).parse_wkt('MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))')
    end

    it 'is nil without a recorded source and credits OpenStreetMap once one is recorded', :aggregate_failures do
      settlement.space.update!(boundary: polygon)
      expect(map.boundary_credit).to be_nil

      settlement.space.update!(metadata: { 'boundary_source' => { 'osm_type' => 'relation', 'osm_id' => 7 } })
      expect(map.boundary_credit.attribution).to eq('Boundary: OpenStreetMap')
    end
  end
end
