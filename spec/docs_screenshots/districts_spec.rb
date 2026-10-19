# frozen_string_literal: true

require 'rails_helper'

# Documentation screenshots for the electoral district pages (desktop and mobile, plain and annotated).
#
#   RUN_DOCS_SCREENSHOTS=1 ./bin/dc-run bundle exec rspec spec/docs_screenshots/districts_spec.rb
#
# Assets land in docs/screenshots/{desktop,mobile}/. Open each PNG and confirm the target is in frame.
RSpec.describe 'Documentation screenshots for electoral districts', :js, type: :feature do
  include RequestSpecHelper

  let(:data_path) { Rails.root.join('db/data/nl_regions/provincial_electoral_districts_2015.geojson') }
  let(:locale) { I18n.default_locale }

  before do
    skip 'set RUN_DOCS_SCREENSHOTS=1 to capture documentation screenshots' unless ENV['RUN_DOCS_SCREENSHOTS']

    configure_host_platform.update!(privacy: 'public')
    NewfoundlandLabradorOnline::Geography::ProvincialDistrictLoader.new(path: data_path).call
    NewfoundlandLabradorOnline::Geography::PoliticalPartyLoader.new.call
    NewfoundlandLabradorOnline::Geography::ProvincialElectionLoader.new.call
    settlement = create(:geography_settlement, identifier: 'corner-brook', name: 'Corner Brook')
    space = BetterTogether::Geography::Space.create!(latitude: 48.95, longitude: -57.95)
    BetterTogether::Geography::GeospatialSpace.create!(geospatial: settlement, space:)
  end

  def captured(slug, callouts)
    DocsScreenshots.capture(page, slug, callouts:).map { |path| File.size(path) }
  end

  it 'captures the district index' do
    visit "/#{locale}/districts"

    callouts = [{ selector: '#listing-map-section', title: 'Districts coloured by party' },
                { selector: '#districts-party-legend', title: 'Party legend with seat counts' },
                { selector: '#districts-list', title: 'All 40 districts' }]

    expect(captured('districts_index', callouts)).to all(be > 10_000)
  end

  it 'captures the Corner Brook district page' do
    visit "/#{locale}/districts/nl-ped-corner-brook"
    callouts = %w[#district-map-section #district-member #district-facts #district-settlements #district-members
                  #district-results #district-history].map do |selector|
      { selector:, title: selector.delete_prefix('#district-').tr('-', ' ') }
    end

    expect(captured('district_show', callouts)).to all(be > 10_000)
  end
end
