# frozen_string_literal: true

require 'rails_helper'

# The boundary data credit is shown by Leaflet's attribution control, with the basemap credit.
RSpec.describe 'Map data attribution', :js, type: :feature do
  include RequestSpecHelper

  before do
    unless ENV['CI'] || system('command -v chromium google-chrome > /dev/null 2>&1')
      skip 'Chrome is not installed (set CI=true to require it)'
    end

    configure_host_platform.update!(privacy: 'public')
    NewfoundlandLabradorOnline::Geography::ProvincialDistrictLoader.new(
      path: Rails.root.join('spec/fixtures/nl_regions/two_districts.geojson')
    ).call
  end

  it 'credits the commission and the licence on the district page', :aggregate_failures do
    visit "/#{I18n.default_locale}/e/districts/provincial/nl/nl-ped-corner-brook"

    expect(page).to have_css('.leaflet-control-attribution a', text: 'Electoral Boundaries Commission (OGL-NL)')
    expect(page).to have_css('.leaflet-control-attribution', text: 'OpenStreetMap')
  end
end
