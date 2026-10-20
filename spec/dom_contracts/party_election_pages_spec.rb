# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/ExampleLength
# Stable identifiers and query budgets for the party and election pages and the district cards.
RSpec.describe 'Party and election pages', type: :request do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:fixtures) { Rails.root.join('spec/fixtures/nl_regions') }

  before do
    configure_host_platform
    districts = NewfoundlandLabradorOnline::Geography::ProvincialDistrictLoader
    districts.new(path: fixtures.join('two_districts.geojson')).call
    NewfoundlandLabradorOnline::Geography::PoliticalPartyLoader.new.call
    NewfoundlandLabradorOnline::Geography::ProvincialElectionLoader.new(path: fixtures.join('two_elections.json')).call
  end

  def query_count(path)
    count = 0
    counter = ->(*, payload) { count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') { get path }
    count
  end

  it 'shows district cards with member and party', :aggregate_failures do
    get "/#{locale}/e/districts/provincial"

    expect(response.body).to include('class="newfoundland_labrador_online_provincial_electoral_district',
                                     'district-card')
    expect(response.body).to include('id="card_member_newfoundland_labrador_online_provincial_electoral_district_')
    expect(response.body).to include('id="card_party_newfoundland_labrador_online_provincial_electoral_district_')
  end

  it 'lists parties with seats and links each to its page', :aggregate_failures do
    get "/#{locale}/e/parties"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="parties-index"', 'id="parties-list-provincial-nl"')
    expect(response.body).to include("/#{locale}/e/parties/provincial/nl/liberal")
  end

  it 'shows a party with current and former members linked to their districts', :aggregate_failures do
    get "/#{locale}/e/parties/provincial/nl/liberal"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="party-page"', 'id="party-name"', 'id="party-current-members"',
                                     'id="party-former-members"')
    expect(response.body).to include("/#{locale}/e/districts/provincial/nl/nl-ped-")
  end

  it 'scopes the indexes by jurisdiction and lists only parties that have held seats', :aggregate_failures do
    get "/#{locale}/e/parties/provincial/nl"
    expect(response.body).to include('Provincial political parties', 'Newfoundland and Labrador',
                                     '/parties/provincial/nl/liberal')
    expect(response.body).not_to include('nl-alliance')

    get "/#{locale}/e/elections/provincial/nl"
    expect(response.body).to include('Provincial elections', 'Provincial general election 2019')
  end

  it 'resolves the province segment from the geography states', :aggregate_failures do
    get "/#{locale}/e/districts/provincial/nl"
    expect(response.body).to include('Newfoundland and Labrador', "/#{locale}/e/districts/provincial/nl/nl-ped-")

    %w[districts/provincial/zz parties/provincial/zz elections/provincial/zz
       elections/provincial/zz/2019].each do |path|
      get "/#{locale}/e/#{path}"
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'associates districts, parties and elections with the province', :aggregate_failures do
    province = BetterTogether::Geography::State.find_by!(iso_code: 'CA-NL')

    expect(province.provincial_electoral_districts.count).to eq(2)
    expect(province.political_parties.pluck(:jurisdiction).uniq).to eq(['provincial'])
    expect(province.elections.pluck(:jurisdiction).uniq).to eq(['provincial'])
  end

  it 'returns 404 for an unknown party' do
    get "/#{locale}/e/parties/provincial/nl/nope"

    expect(response).to have_http_status(:not_found)
  end

  it 'lists elections and shows one with linked parties and districts', :aggregate_failures do
    get "/#{locale}/e/elections"
    expect(response.body).to include('id="elections-index"', "/#{locale}/e/elections/provincial/nl/2019")

    get "/#{locale}/e/elections/provincial/nl/2019"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="election-page"', 'id="election-name"',
                                     "/#{locale}/e/districts/provincial/nl/")
  end

  it 'keeps query counts independent of the number of pages rows', :aggregate_failures do
    paths = ["/#{locale}/e/districts/provincial", "/#{locale}/e/parties", "/#{locale}/e/parties/provincial/nl/liberal",
             "/#{locale}/e/elections", "/#{locale}/e/elections/provincial/nl/2019"]
    paths.each { |path| get path } # warm caches
    counts = paths.to_h { |path| [path, query_count(path)] }

    expect(counts.values).to all(be < 70)
  end
end
# rubocop:enable RSpec/ExampleLength
