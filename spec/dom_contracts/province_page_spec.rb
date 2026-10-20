# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/ExampleLength
# The public province pages (under /g like settlements) list the data associated with each province.
RSpec.describe 'State and province pages', type: :request do
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

  it 'lists provinces and links each to its alias page without signing in', :aggregate_failures do
    get "/#{locale}/g/provinces"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="states-index"', "/#{locale}/g/provinces/nl", 'Newfoundland and Labrador')
  end

  it 'serves the canonical state routes for any state, by slug or code', :aggregate_failures do
    state = BetterTogether::Geography::State.find_by!(iso_code: 'CA-NL')
    get "/#{locale}/g/states"
    expect(response.body).to include('id="states-index"', "/#{locale}/g/provinces/nl")

    get "/#{locale}/g/states/#{state.slug}"
    expect(response.body).to include('id="state-page"', 'id="province-districts"')
  end

  it 'keeps non-provinces off the provinces alias', :aggregate_failures do
    other = create(:geography_state)
    get "/#{locale}/g/states/#{other.slug}"
    expect(response).to have_http_status(:ok)

    get "/#{locale}/g/provinces/#{other.slug}"
    expect(response).to have_http_status(:not_found)
    get "/#{locale}/g/provinces"
    expect(response.body).not_to include(other.name)
  end

  it 'links to the province districts, parties and elections', :aggregate_failures do
    get "/#{locale}/g/provinces/nl"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="province-districts"', "/#{locale}/e/districts/provincial/nl/nl-ped-",
                                     'id="province-parties"', "/#{locale}/e/parties/provincial/nl/liberal",
                                     'id="province-elections"', "/#{locale}/e/elections/provincial/nl/2019")
    expect(response.body).not_to include('Manage this province')
  end

  it 'offers management only to platform managers' do
    login('manager@example.test', 'SecureTest123!@#')
    get "/#{locale}/g/provinces/nl"

    expect(response.body).to include('Manage this province')
  end

  it 'answers 404 for an unknown province' do
    get "/#{locale}/g/provinces/zz"

    expect(response).to have_http_status(:not_found)
  end

  it 'follows the settlement policy pattern', :aggregate_failures do
    province = BetterTogether::Geography::State.find_by!(iso_code: 'CA-NL')
    policy = BetterTogether::Geography::StatePolicy.new(nil, province)

    expect(policy.index?).to be(true)
    expect(policy.show?).to be(true)
    expect(policy.update?).to be(false)
    expect(policy.destroy?).to be(false)
  end
end
# rubocop:enable RSpec/ExampleLength
