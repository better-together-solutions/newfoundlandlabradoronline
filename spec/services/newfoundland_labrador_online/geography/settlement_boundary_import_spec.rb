# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Geography::SettlementBoundaryImport do
  include RequestSpecHelper

  before do
    configure_host_platform
    space.update!(latitude: 47.55, longitude: -52.75)
    allow(Geocoder).to receive(:search).and_return([instance_double(Geocoder::Result::Base, data:)])
  end

  let(:province) { BetterTogether::Geography::State.find_by!(iso_code: 'CA-NL') }
  let(:settlement) { create(:geography_settlement, name: "St. John's", state: province, country: province.country) }
  let(:space) { settlement.space || settlement.create_space }
  let(:square) do
    { 'type' => 'Polygon',
      'coordinates' => [[[-52.8, 47.5], [-52.8, 47.6], [-52.7, 47.6], [-52.7, 47.5], [-52.8, 47.5]]] }
  end
  let(:data) do
    { 'class' => 'boundary', 'osm_type' => 'relation', 'osm_id' => 2_805_426, 'display_name' => "St. John's",
      'geojson' => square }
  end

  def boundary_credit(record)
    NewfoundlandLabradorOnline::Geography::BoundaryCredit.for_space(record)
  end

  def run(**)
    described_class.new(settlement:, **).call
  end

  it 'searches with the province and country, not the bare name' do
    expect(run.query).to eq("St. John's, Newfoundland and Labrador, #{province.country.name}")
  end

  it 'reports what it would import and writes nothing on a dry run', :aggregate_failures do
    result = run

    expect(result).to have_attributes(status: :would_import, osm_id: 2_805_426, covers_point: true)
    expect(result.area_km2).to be > 50
    expect(space.reload.boundary).to be_nil
  end

  it 'stores the boundary and its OSM source when applied', :aggregate_failures do
    expect(run(apply: true).status).to eq(:imported)

    space.reload
    expect(space.boundary).to be_present
    expect(space.metadata.dig('boundary_source', 'osm_id')).to eq(2_805_426)
    expect(boundary_credit(space).label).to eq('Boundary: OpenStreetMap (ODbL)')
  end

  it 'refuses a result that is not an administrative boundary polygon' do
    data['class'] = 'place'

    expect(run(apply: true).status).to eq(:not_a_boundary)
  end

  it 'refuses a polygon that does not cover the settlement point' do
    space.update!(latitude: 10.0, longitude: 10.0)

    expect(run(apply: true).status).to eq(:point_outside)
  end

  it 'leaves an existing boundary alone unless forced' do
    run(apply: true)

    expect(run(apply: true).status).to eq(:already_has_boundary)
  end
end
