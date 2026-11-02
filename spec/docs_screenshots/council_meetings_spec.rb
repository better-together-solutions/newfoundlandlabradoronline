# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/MultipleExpectations
# Documentation screenshots for the council meetings tab (desktop and mobile, plain and annotated).
#
#   RUN_DOCS_SCREENSHOTS=1 ./bin/dc-run bundle exec rspec spec/docs_screenshots/council_meetings_spec.rb
#
# Assets land in docs/screenshots/{desktop,mobile}/. Open each PNG and confirm the target is in frame.
RSpec.describe 'Documentation screenshots for council meetings', :js, type: :feature do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }

  before do
    skip 'set RUN_DOCS_SCREENSHOTS=1 to capture documentation screenshots' unless ENV['RUN_DOCS_SCREENSHOTS']

    configure_host_platform.update!(privacy: 'public')
    corner_brook_council
    import_meetings
    visit "/#{locale}/e/municipalities/nl/corner-brook/meetings"
  end

  def captured(slug, callouts, scroll_to: nil)
    paths = DocsScreenshots.capture(page, slug, callouts:) do
      page.execute_script("document.querySelector('#{scroll_to}').scrollIntoView({ block: 'center' })") if scroll_to
    end
    paths.map { |path| File.size(path) }
  end

  it 'captures the meetings timeline with its filters' do
    callouts = [{ selector: '#meeting-filters', title: 'One toggle per meeting type, all on' },
                { selector: '#meetings-timeline', title: 'One timeline; documents link to the portal' }]

    expect(captured('council_meetings', callouts, scroll_to: '#council-meetings')).to all(be > 10_000)
  end

  it 'captures the timeline with one meeting type switched off' do
    find('#meeting-filter-meeting-committee_of_the_whole').click
    expect(page).to have_css('#meeting-filter-meeting-committee_of_the_whole[aria-pressed="false"]')
    page.has_css?('.meeting-row[hidden]', visible: :hidden, minimum: 1, wait: 5)

    callouts = [{ selector: '#meeting-filters', title: 'Committee of the Whole switched off' }]

    expect(captured('council_meetings_filtered', callouts, scroll_to: '#council-meetings')).to all(be > 10_000)
  end

  it 'captures the council as host on its event page' do
    meeting = NewfoundlandLabradorOnline::Meeting.find_by!(source_id: '11111111-aaaa-4aaa-8aaa-000000000001')
    visit better_together.event_path(meeting.event, locale:)
    callouts = [{ selector: '#event-description', title: 'Documents, all-meetings link and the recording' },
                { selector: '.municipality-host-card', title: 'Council host card links to the municipality page' }]

    expect(captured('council_meeting_event_host', callouts, scroll_to: '.municipality-host-card')).to all(be > 10_000)
  end
end
# rubocop:enable RSpec/MultipleExpectations
