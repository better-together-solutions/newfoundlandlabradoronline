# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Geography::DistrictCoverInputs do
  include RequestSpecHelper

  let(:path) { Rails.root.join('spec/fixtures/nl_regions/two_districts.geojson') }
  let(:fallback) { NewfoundlandLabradorOnline::PoliticalParty::FALLBACK_COLOR }

  before do
    configure_host_platform
    NewfoundlandLabradorOnline::Geography::ProvincialDistrictLoader.new(path:).call
  end

  it 'describes each district: geometry, credit, fallback colour with no party', :aggregate_failures do
    entry = described_class.call.fetch('Corner Brook')

    expect(entry).to include(slug: 'nl-ped-corner-brook', color: fallback, kind: 'Provincial electoral district')
    expect(entry[:geometry]['type']).to include('Polygon')
    expect(entry[:authority]).to be_present
  end

  it 'colours a district by the sitting member\'s current party, not the party elected' do
    region = NewfoundlandLabradorOnline::ProvincialElectoralDistrict.find_by!(identifier: 'nl-ped-corner-brook')
    independent = NewfoundlandLabradorOnline::PoliticalParty.new(color: nil)
    holding = instance_double(NewfoundlandLabradorOnline::Civic::Holding, region_id: region.id, party_on: independent)
    allow(NewfoundlandLabradorOnline::Civic::Roster).to receive(:current_holdings).and_return([holding])

    expect(described_class.call.fetch('Corner Brook')[:color]).to eq(fallback)
  end
end
