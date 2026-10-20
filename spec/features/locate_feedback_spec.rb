# frozen_string_literal: true

require 'rails_helper'

# The locate button shows a spinning globe while fetching, then a check, and the map frames the position.
RSpec.describe 'Locate me feedback', :js, type: :feature do
  include RequestSpecHelper

  let(:path) { Rails.root.join('spec/fixtures/nl_regions/two_districts.geojson') }

  before do
    unless ENV['CI'] || system('command -v chromium google-chrome > /dev/null 2>&1')
      skip 'Chrome is not installed (set CI=true to require it)'
    end

    configure_host_platform.update!(privacy: 'public')
    NewfoundlandLabradorOnline::Geography::ProvincialDistrictLoader.new(path:).call
  end

  def stub_geolocation
    page.execute_script(<<~JS)
      navigator.geolocation.getCurrentPosition = function (ok) {
        window.resolveLocate = function () { ok({ coords: { latitude: 48.95, longitude: -57.95, accuracy: 120 } }) }
      }
    JS
  end

  # rubocop:disable-next RSpec/ExampleLength
  it 'spins a globe while locating, then confirms and zooms in', :aggregate_failures do
    visit "/#{I18n.default_locale}/e/districts/provincial/nl/nl-ped-corner-brook"
    stub_geolocation
    find('[data-geolocation-button]').click

    expect(page).to have_css('[data-geolocation-button] i.fa-spin')
    page.execute_script('window.resolveLocate()')
    expect(page).to have_css('[data-geolocation-button] i.fa-check')
    expect(page).to have_css('[data-geolocation-button].btn-success')
  end
end
