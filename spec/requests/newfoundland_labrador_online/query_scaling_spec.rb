# frozen_string_literal: true

require 'rails_helper'

# Page query counts must not grow with the number of districts, members, parties or elections (no N+1).
RSpec.describe 'Query scaling', type: :request do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:dir) { Dir.mktmpdir }
  let(:paths) do
    ["/#{locale}/g/provinces/nl", "/#{locale}/e/districts/provincial/nl", "/#{locale}/e/members/provincial/nl",
     "/#{locale}/e/districts/provincial/nl/nl-ped-district-0", "/#{locale}/e/parties/provincial/nl",
     "/#{locale}/e/parties/provincial/nl/liberal", "/#{locale}/e/elections",
     "/#{locale}/e/elections/provincial/nl/2019"]
  end

  after { FileUtils.remove_entry(dir) }

  before { configure_host_platform.update!(privacy: 'public') }

  def features(count)
    (0...count).map do |i|
      x = -58.0 + (i * 0.05)
      { type: 'Feature',
        properties: { name: "District #{i}", source_sha256: "s#{i}", authority: 'Test', valid_from: '2015-11-30',
                      valid_to: nil, license: 'OGL', source_url: 'https://example.test' },
        geometry: { type: 'MultiPolygon',
                    coordinates: [[[[x, 48.9], [x, 49.0], [x + 0.04, 49.0], [x + 0.04, 48.9], [x, 48.9]]]] } }
    end
  end

  def elections(count)
    parties = %w[Liberal PC NDP]
    results = (0...count).map do |i|
      { district: "District #{i}", turnout: 50.0,
        candidates: parties.each_with_index.map do |party, j|
          { candidate: "Candidate #{i}-#{j}", votes: 1000 - (j * 100), share: 40.0 - j, wikipedia_path: nil, party:,
            elected: j.zero? }
        end }
    end
    { elections: [{ year: 2019, date: '2019-05-16', source_url: 'https://example.test/2019', source_revid: 1,
                    source_sha256: 'a', license: 'CC BY-SA 4.0', districts: results }] }
  end

  def write_json(name, data)
    Pathname(File.join(dir, name)).tap { |file| file.write(data.to_json) }
  end

  def load_data(count)
    geo = NewfoundlandLabradorOnline::Geography
    geo::ProvincialDistrictLoader.new(path: write_json("d#{count}.geojson",
                                                       { type: 'FeatureCollection', features: features(count) })).call
    geo::PoliticalPartyLoader.new.call
    geo::ProvincialElectionLoader.new(path: write_json("e#{count}.json", elections(count))).call
  end

  def query_count(path)
    count = 0
    counter = ->(*, payload) { count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') { get path }
    expect(response).to have_http_status(:ok), "#{path} => #{response.status}"
    count
  end

  def counts
    paths.each { |path| get path }
    paths.to_h { |path| [path, query_count(path)] }
  end

  it 'does not add queries as the data grows', :aggregate_failures do
    load_data(3)
    small = counts
    load_data(12)
    large = counts

    small.each { |path, n| expect(large[path]).to be <= n + 2, "#{path}: #{n} -> #{large[path]}" }
  end
end
