# frozen_string_literal: true

require 'rails_helper'

# Municipality page query counts must not grow with the number of municipalities, councillors or elections.
RSpec.describe 'Municipality query scaling', type: :request do # rubocop:disable RSpec/MultipleMemoizedHelpers
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:dir) { Dir.mktmpdir }
  let(:province) { BetterTogether::Geography::State.find_by!(iso_code: 'CA-NL') }
  let(:councils) { JSON.parse(NewfoundlandLabradorOnline::Civic::MunicipalRosterLoader::DEFAULT_PATH.read) }
  let(:elections) { JSON.parse(NewfoundlandLabradorOnline::Civic::MunicipalElectionLoader::DEFAULT_PATH.read) }
  let(:paths) do
    ["/#{locale}/e/municipalities/nl", "/#{locale}/e/municipalities/nl/town-0",
     "/#{locale}/e/elections/municipal/nl/town-0/2025", "/#{locale}/g/settlements/town-0"]
  end

  before do
    configure_host_platform.update!(privacy: 'public')
    load_towns(3)
    small
  end

  after { FileUtils.remove_entry(dir) }

  def small = (@small ||= counts)

  def load_towns(range_end, from: 0)
    (from...range_end).each do |i|
      create(:geography_settlement, identifier: "town-#{i}", name: "Town #{i}", state: province)
    end
    write_packets(from...range_end)
  end

  def write_packets(range)
    c = range.map { |i| council_entry(i) }
    e = range.map { |i| election_entry(i) }
    NewfoundlandLabradorOnline::Civic::MunicipalRosterLoader.new(path: write('c', c, 'councils'), apply: true).call
    NewfoundlandLabradorOnline::Civic::MunicipalElectionLoader.new(path: write('e', e, 'elections'), apply: true).call
  end

  def council_entry(index)
    council = councils['councils'].first
    council.merge('settlement' => "town-#{index}", 'statcan_csd' => "9#{index.to_s.rjust(6, '0')}",
                  'officials' => people(council, index))
  end

  def election_entry(index)
    election = elections['elections'].first
    election.merge('settlement' => "town-#{index}", 'contests' => contests(election, index))
  end

  def people(council, index)
    council['officials'].map { |o| o.merge('name' => "#{o['name']} #{index}") }
  end

  def contests(election, index)
    election['contests'].map do |contest|
      contest.merge('candidates' => contest['candidates'].map { |c| c.merge('name' => "#{c['name']} #{index}") })
    end
  end

  def write(name, rows, key)
    Pathname(File.join(dir, "#{name}#{rows.size}-#{rows.first['settlement']}.json")).tap do |f|
      f.write({ key => rows }.to_json)
    end
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

  it 'does not add queries as municipalities are added', :aggregate_failures do
    load_towns(15, from: 3)

    small.each { |path, n| expect(counts[path]).to be <= n + 2, "#{path}: #{n} -> #{counts[path]}" }
  end
end
