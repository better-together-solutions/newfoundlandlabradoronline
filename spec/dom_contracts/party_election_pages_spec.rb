# frozen_string_literal: true

require 'rails_helper'

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

  it 'redirects the old districts paths', :aggregate_failures do
    get "/#{locale}/districts"
    expect(response).to redirect_to("/#{locale}/g/districts/provincial")
    get "/#{locale}/districts/nl-ped-corner-brook"
    expect(response).to redirect_to("/#{locale}/g/districts/provincial/nl-ped-corner-brook")
  end

  it 'shows district cards with member and party', :aggregate_failures do
    get "/#{locale}/g/districts/provincial"

    expect(response.body).to include('class="newfoundland_labrador_online_provincial_electoral_district',
                                     'district-card')
    expect(response.body).to include('id="card_member_newfoundland_labrador_online_provincial_electoral_district_')
    expect(response.body).to include('id="card_party_newfoundland_labrador_online_provincial_electoral_district_')
  end

  it 'lists parties with seats and links each to its page', :aggregate_failures do
    get "/#{locale}/parties"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="parties-index"', 'id="parties-list"')
    expect(response.body).to include("/#{locale}/parties/provincial-nl/liberal")
  end

  it 'shows a party with current and former members linked to their districts', :aggregate_failures do
    get "/#{locale}/parties/provincial-nl/liberal"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="party-page"', 'id="party-name"', 'id="party-current-members"',
                                     'id="party-former-members"')
    expect(response.body).to include("/#{locale}/g/districts/provincial/nl-ped-")
  end

  it 'returns 404 for an unknown party' do
    get "/#{locale}/parties/provincial-nl/nope"

    expect(response).to have_http_status(:not_found)
  end

  it 'lists elections and shows one with linked parties and districts', :aggregate_failures do
    get "/#{locale}/elections"
    expect(response.body).to include('id="elections-index"', "/#{locale}/elections/provincial/2019")

    get "/#{locale}/elections/provincial/2019"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="election-page"', 'id="election-name"', "/#{locale}/g/districts/provincial/")
  end

  it 'keeps query counts independent of the number of pages rows', :aggregate_failures do
    paths = ["/#{locale}/g/districts/provincial", "/#{locale}/parties", "/#{locale}/parties/provincial-nl/liberal",
             "/#{locale}/elections", "/#{locale}/elections/provincial/2019"]
    paths.each { |path| get path } # warm caches
    counts = paths.to_h { |path| [path, query_count(path)] }

    expect(counts.values).to all(be < 70)
  end
end
