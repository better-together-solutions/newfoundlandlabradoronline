# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Geography::ProvincialDistrictLoader do
  include RequestSpecHelper

  let(:path) { Rails.root.join('spec/fixtures/nl_regions/two_districts.geojson') }
  let(:district) { NewfoundlandLabradorOnline::ProvincialElectoralDistrict }
  let(:versions) { NewfoundlandLabradorOnline::RegionVersion }
  let(:corner_brook) { district.find_by!(identifier: 'nl-ped-corner-brook').reload }

  before { configure_host_platform }

  describe 'first load' do
    let!(:result) { described_class.new(path:).call }

    it 'creates both districts with an identifier and a current version', :aggregate_failures do
      expect(result.created.size).to eq(2)
      expect(corner_brook.name).to eq('Corner Brook')
      expect(corner_brook.identifier_for('nlo_ped')).to eq('nl-ped-corner-brook')
      expect(corner_brook.current_version.area_km2).to be_between(200, 300)
    end

    it 'caches the boundary and a representative point on the region space', :aggregate_failures do
      expect(corner_brook.space.boundary).to be_present
      expect(corner_brook.space.latitude).to be_between(48.9, 49.0)
    end

    it 'places a point in the district that contains it' do
      containing = versions.where('ST_Covers(boundary, ST_SetSRID(ST_Point(?, ?), 4326)::geography)', -57.95, 48.95)

      expect(containing.map { |v| v.region.name }).to eq(['Corner Brook'])
    end
  end

  it 'is idempotent' do
    described_class.new(path:).call

    expect { described_class.new(path:).call }.not_to(change { [district.count, versions.count] })
  end

  it 'rewrites a boundary when the source checksum changes' do
    described_class.new(path:).call
    versions.find_each { |version| version.update!(source_sha256: 'old') }

    expect(described_class.new(path:).call.updated.size).to eq(2)
  end
end
