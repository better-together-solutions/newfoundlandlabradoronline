# frozen_string_literal: true

require 'rails_helper'

# Documentation screenshots for the municipality pages (desktop and mobile, plain and annotated).
#
#   RUN_DOCS_SCREENSHOTS=1 ./bin/dc-run bundle exec rspec spec/docs_screenshots/municipalities_spec.rb
#
# Assets land in docs/screenshots/{desktop,mobile}/. Open each PNG and confirm the target is in frame.
RSpec.describe 'Documentation screenshots for municipalities', :js, type: :feature do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }

  before do
    skip 'set RUN_DOCS_SCREENSHOTS=1 to capture documentation screenshots' unless ENV['RUN_DOCS_SCREENSHOTS']

    configure_host_platform.update!(privacy: 'public')
    province = BetterTogether::Geography::State.find_by!(iso_code: 'CA-NL')
    { 'corner-brook' => 'Corner Brook', 'st-john-s' => "St. John's" }.each do |identifier, name|
      create(:geography_settlement, identifier:, name:, state: province)
    end
    NewfoundlandLabradorOnline::Civic::MunicipalRosterLoader.new(apply: true).call
    NewfoundlandLabradorOnline::Civic::MunicipalElectionLoader.new(apply: true).call
    NewfoundlandLabradorOnline::Civic::WardBoundaryLoader.new(apply: true).call
  end

  # scroll_to centres a target in the frame first, for sections below the fold.
  def captured(slug, callouts, scroll_to: nil)
    paths = DocsScreenshots.capture(page, slug, callouts:) do
      page.execute_script("document.querySelector('#{scroll_to}').scrollIntoView({ block: 'center' })") if scroll_to
    end
    paths.map { |path| File.size(path) }
  end

  it 'captures the municipalities index' do
    visit "/#{locale}/e/municipalities/nl"

    callouts = [{ selector: '#municipalities-list', title: 'Municipalities with a council' }]

    expect(captured('municipalities_index', callouts)).to all(be > 10_000)
  end

  context 'with the St. John\'s municipality page' do
    let(:callouts) do
      [['#municipality-facts', 'Facts and status source'], ['#municipality-leaders', 'Mayor and deputy mayor'],
       ['#council-members', 'Councillors by ward'], ['#municipality-election', 'Latest election']]
        .map { |selector, title| { selector:, title: } }
    end

    before { visit "/#{locale}/e/municipalities/nl/st-john-s" }

    it 'captures the whole page' do
      expect(captured('municipality_show', callouts)).to all(be > 10_000)
    end

    it 'captures the ward map' do
      callouts = [{ selector: '#municipality-ward-map', title: 'Ward map and source' }]
      page.has_css?('#municipality-ward-map path.leaflet-interactive', count: 5, wait: 15)

      expect(captured('municipality_show_ward_map', callouts, scroll_to: '#municipality-ward-map')).to all(be > 10_000)
    end

    it 'captures the council table' do
      expect(captured('municipality_show_council', callouts.slice(2, 1), scroll_to: '#council-members'))
        .to all(be > 10_000)
    end

    it 'captures the latest election' do
      expect(captured('municipality_show_election', callouts.slice(3, 1), scroll_to: '#municipality-election'))
        .to all(be > 10_000)
    end
  end

  it 'captures a municipal election page' do
    visit "/#{locale}/e/elections/municipal/nl/st-john-s/2025"

    callouts = [{ selector: '#election-source', title: 'Source of the results' }]

    expect(captured('municipal_election_show', callouts)).to all(be > 10_000)
  end

  it 'captures the settlement page card' do
    visit "/#{locale}/g/settlements/corner-brook"

    callouts = [{ selector: '#settlement-municipal-card', title: 'Link to the municipality' }]

    expect(captured('settlement_municipal_card', callouts, scroll_to: '#settlement-municipal-card'))
      .to all(be > 10_000)
  end
end
