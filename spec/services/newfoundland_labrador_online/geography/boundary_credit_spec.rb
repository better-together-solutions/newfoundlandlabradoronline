# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Geography::BoundaryCredit do
  let(:polygon) do
    RGeo::Geographic.spherical_factory(srid: 4326).parse_wkt('MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))')
  end

  def space_with(source, boundary: polygon)
    BetterTogether::Geography::Space.new(boundary:, metadata: { 'boundary_source' => source }.compact)
  end

  describe '.for_version' do
    let(:version) do
      NewfoundlandLabradorOnline::RegionVersion.new(authority: 'Electoral Boundaries Commission',
                                                    source_url: 'https://example.test/361',
                                                    license: 'Open Government Licence')
    end

    it 'credits a district version as one linked line' do
      expect(described_class.for_version(version).to_h)
        .to eq(attribution: 'Electoral Boundaries Commission (Open Government Licence)',
               attribution_url: 'https://example.test/361')
    end

    it 'credits nothing without a version or an authority' do
      expect([described_class.for_version(nil), described_class.for_version(NewfoundlandLabradorOnline::RegionVersion.new)])
        .to all(be_nil)
    end
  end

  describe '.for_space' do
    it 'credits OpenStreetMap under the ODbL, linked to the source object', :aggregate_failures do
      credit = described_class.for_space(space_with({ 'provider' => 'nominatim', 'osm_type' => 'relation',
                                                      'osm_id' => 1_234 }))

      expect(credit.attribution).to eq('Boundary: OpenStreetMap')
      expect(credit.attribution_url).to eq('https://www.openstreetmap.org/relation/1234')
      expect(credit.label).to eq('Boundary: OpenStreetMap (ODbL)')
    end

    it 'credits nothing when the source is unknown, missing or has no polygon', :aggregate_failures do
      expect(described_class.for_space(space_with(nil))).to be_nil
      expect(described_class.for_space(space_with({ 'provider' => 'nominatim', 'status' => 'no_polygon' }))).to be_nil
      unbounded = space_with({ 'osm_type' => 'relation', 'osm_id' => 5 }, boundary: nil)
      expect(described_class.for_space(unbounded)).to be_nil
    end

    it 'does not build a link from an unexpected osm type or id', :aggregate_failures do
      expect(described_class.for_space(space_with({ 'osm_type' => 'javascript:', 'osm_id' => 5 }))).to be_nil
      credit = described_class.for_space(space_with({ 'osm_type' => 'way', 'osm_id' => 'abc' }))
      expect(credit.attribution_url).to eq('https://www.openstreetmap.org/copyright')
    end
  end
end
