# frozen_string_literal: true

require 'rails_helper'

# Documentation screenshots for the settlement boundary credit (desktop and mobile, plain and annotated).
#
#   RUN_DOCS_SCREENSHOTS=1 ./bin/dc-run bundle exec rspec spec/docs_screenshots/settlement_boundary_credit_spec.rb
RSpec.describe 'Documentation screenshots for the settlement boundary credit', :js, type: :feature do
  include RequestSpecHelper

  let(:polygon) do
    RGeo::Geographic.spherical_factory(srid: 4326)
                    .parse_wkt('MULTIPOLYGON(((-58.01 48.93,-58.01 48.98,-57.9 48.98,-57.9 48.93,-58.01 48.93)))')
  end

  before do
    skip 'set RUN_DOCS_SCREENSHOTS=1 to capture documentation screenshots' unless ENV['RUN_DOCS_SCREENSHOTS']

    configure_host_platform.update!(privacy: 'public')
    settlement = create(:geography_settlement, identifier: 'corner-brook', name: 'Corner Brook')
    space = BetterTogether::Geography::Space.create!(
      latitude: 48.95, longitude: -57.95, boundary: polygon,
      metadata: { 'boundary_source' => { 'osm_type' => 'relation', 'osm_id' => 1_234 } }
    )
    BetterTogether::Geography::GeospatialSpace.create!(geospatial: settlement, space:)
  end

  it 'captures the credit under the settlement map' do
    visit "/#{I18n.default_locale}/g/settlements/corner-brook"
    callouts = [{ selector: '#settlement-map', title: 'Boundary drawn on the map' },
                { selector: '#settlement-boundary-credit', title: 'Boundary credit, one link' }]

    expect(DocsScreenshots.capture(page, 'settlement_boundary_credit', callouts:).map { |p| File.size(p) })
      .to all(be > 10_000)
  end
end
