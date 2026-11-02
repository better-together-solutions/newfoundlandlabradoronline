# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Civic::WardBoundaryFetcher do
  let(:path) { Rails.root.join("tmp/ward_fetch_spec_#{SecureRandom.hex(4)}.geojson") }
  let(:geometry) { { 'type' => 'Polygon', 'coordinates' => [[[0, 0], [0, 1], [1, 1], [0, 0]]] } }
  let(:body) do
    { 'features' => [{ 'type' => 'Feature', 'properties' => { 'WARD' => 2, 'WARDNAME' => 'WARD 2' },
                       'geometry' => geometry }] }.to_json
  end
  let(:response) { Net::HTTPOK.new('1.1', '200', 'OK').tap { |r| allow(r).to receive(:body).and_return(body) } }

  before { allow(Net::HTTP).to receive(:start).and_return(response) }

  after { FileUtils.rm_f(path) }

  it 'builds a packet that names the authority and the download portal', :aggregate_failures do
    props = described_class.new(path:).call['features'].first['properties']

    expect(props).to include('seat' => 'Ward 2', 'authority' => "City of St. John's", 'license' => nil,
                             'source_sha256' => Digest::SHA256.hexdigest(body))
    expect(props['portal_url']).to start_with('https://map.stjohns.ca/')
  end

  it 'writes the packet only when asked', :aggregate_failures do
    described_class.new(path:).call
    expect(File).not_to exist(path)

    described_class.new(path:, write: true).call
    expect(File).to exist(path)
  end

  it 'refuses a failed response' do
    allow(response).to receive(:is_a?).and_call_original
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)

    expect { described_class.new(path:).call }.to raise_error(/HTTP/)
  end
end
