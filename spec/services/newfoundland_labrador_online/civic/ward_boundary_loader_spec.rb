# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Civic::WardBoundaryLoader do
  include RequestSpecHelper

  before do
    configure_host_platform
    NewfoundlandLabradorOnline::Civic::MunicipalRosterLoader.new(path: roster_path, apply: true).call
  end

  after { Dir[Rails.root.join('tmp/ward_spec_*.json')].each { |file| FileUtils.rm_f(file) } }

  let!(:settlement) { create(:geography_settlement, identifier: 'st-john-s', name: "St. John's") }
  let(:square) do
    { 'type' => 'Polygon',
      'coordinates' => [[[-52.8, 47.5], [-52.8, 47.6], [-52.7, 47.6], [-52.7, 47.5], [-52.8, 47.5]]] }
  end
  let(:roster_path) do
    write('councils' => [{ 'settlement' => settlement.slug, 'council_name' => "St. John's City Council",
                           'seats' => [{ 'name' => 'Ward 1', 'kind' => 'at_large', 'position' => 1 }],
                           'officials' => [] }])
  end

  def write(packet)
    Rails.root.join("tmp/ward_spec_#{SecureRandom.hex(4)}.json").tap { |file| File.write(file, packet.to_json) }
  end

  def packet(sha: 'a' * 64, seat: 'Ward 1')
    { 'features' => [{ 'type' => 'Feature', 'geometry' => square,
                       'properties' => { 'settlement' => settlement.slug, 'seat' => seat,
                                         'authority' => "City of St. John's",
                                         'source_url' => 'https://example.test/layer/2',
                                         'portal_url' => 'https://example.test', 'license' => nil,
                                         'source_sha256' => sha, 'fetched_on' => '2026-11-01' } }] }
  end

  def run(data, apply: true)
    described_class.new(path: write(data), apply:).call
  end

  it 'writes nothing on a dry run' do
    expect { run(packet, apply: false) }.not_to change(NewfoundlandLabradorOnline::SeatBoundary, :count)
  end

  it 'stores the boundary, its area and its source', :aggregate_failures do
    expect(run(packet).created).to eq(['Ward 1'])
    record = NewfoundlandLabradorOnline::SeatBoundary.first
    expect(record).to have_attributes(authority: "City of St. John's", portal_url: 'https://example.test')
    expect(record.boundary).to be_present
    expect(record.area_km2).to be > 50
  end

  it 'leaves an unchanged source alone and rewrites a changed one', :aggregate_failures do
    run(packet)

    expect(run(packet).unchanged).to eq(['Ward 1'])
    expect(run(packet(sha: 'b' * 64)).updated).to eq(['Ward 1'])
  end

  it 'reports a seat that has not been loaded' do
    expect(run(packet(seat: 'Ward 9')).missing_seats).to eq(["#{settlement.slug}/Ward 9"])
  end
end
