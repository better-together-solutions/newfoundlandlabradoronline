# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Geography::BoundaryProvenanceBackfill do
  include RequestSpecHelper

  let(:settlement) { create(:geography_settlement, identifier: 'backfill-town') }
  let(:polygon) do
    RGeo::Geographic.spherical_factory(srid: 4326).parse_wkt('MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))')
  end
  let(:space) { BetterTogether::Geography::Space.create!(latitude: 48.95, longitude: -57.95, boundary: polygon) }

  before do
    configure_host_platform
    BetterTogether::Geography::GeospatialSpace.create!(geospatial: settlement, space:)
    settlement.reload
  end

  def run(apply: false, osm_type: 'relation', osm_id: 42)
    described_class.new(settlement:, osm_type:, osm_id:, apply:).call
  end

  it 'changes nothing on a dry run' do
    expect([run.status, space.reload.metadata['boundary_source']]).to eq([:would_update, nil])
  end

  it 'records the named OSM object once, and leaves it alone on a second run', :aggregate_failures do
    expect(run(apply: true).status).to eq(:updated)
    expect(space.reload.metadata['boundary_source']).to include('osm_type' => 'relation', 'osm_id' => 42)
    expect(run(apply: true, osm_id: 99).status).to eq(:already_sourced)
    expect(space.reload.metadata['boundary_source']['osm_id']).to eq(42)
  end

  it 'refuses an invalid source and a settlement without a boundary', :aggregate_failures do
    expect(run(apply: true, osm_type: 'bogus').status).to eq(:invalid_source)
    space.update!(boundary: nil)
    settlement.reload
    expect(run(apply: true).status).to eq(:no_boundary)
  end
end
