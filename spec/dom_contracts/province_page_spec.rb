# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/ExampleLength
# The province page lists the districts, parties and elections associated with the province.
RSpec.describe 'Province page', type: :request do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:fixtures) { Rails.root.join('spec/fixtures/nl_regions') }

  before do
    configure_host_platform
    districts = NewfoundlandLabradorOnline::Geography::ProvincialDistrictLoader
    districts.new(path: fixtures.join('two_districts.geojson')).call
    NewfoundlandLabradorOnline::Geography::PoliticalPartyLoader.new.call
    NewfoundlandLabradorOnline::Geography::ProvincialElectionLoader.new(path: fixtures.join('two_elections.json')).call
    login('manager@example.test', 'SecureTest123!@#')
  end

  it 'links to the province districts, parties and elections', :aggregate_failures do
    province = BetterTogether::Geography::State.find_by!(iso_code: 'CA-NL')
    get "/#{locale}/host/geography/states/#{province.id}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="province-districts"', "/#{locale}/e/districts/provincial/nl/nl-ped-",
                                     'id="province-parties"', "/#{locale}/e/parties/provincial/nl/liberal",
                                     'id="province-elections"', "/#{locale}/e/elections/provincial/nl/2019")
  end
end
# rubocop:enable RSpec/ExampleLength
