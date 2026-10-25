# frozen_string_literal: true

require 'rails_helper'

# Documentation screenshots for event series (desktop and mobile, plain and annotated).
#
#   RUN_DOCS_SCREENSHOTS=1 ./bin/dc-run bundle exec rspec spec/docs_screenshots/event_series_spec.rb
#
# Assets land in docs/screenshots/{desktop,mobile}/. Open each PNG and confirm the target is in frame.
RSpec.describe 'Documentation screenshots for event series', :js, type: :feature do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:series) do
    create(:better_together_event, series: true, starts_at: nil, ends_at: nil, privacy: 'public',
                                   name: 'A Tribute to Fleetwood Mac')
  end
  let(:friday) { add_session('A Tribute to Fleetwood Mac', 3.days.from_now) }
  let(:saturday) { add_session('Fleetwood Mac Tribute: Matinee', 4.days.from_now) }

  def add_session(name, start)
    create(:better_together_event, starts_at: start, ends_at: start + 2.hours, privacy: 'public', name:,
                                   session_of: series.identifier)
  end

  before do
    skip 'set RUN_DOCS_SCREENSHOTS=1 to capture documentation screenshots' unless ENV['RUN_DOCS_SCREENSHOTS']

    configure_host_platform.update!(privacy: 'public')
    [friday, saturday]
  end

  def sign_in_as_manager
    visit "/#{locale}/users/sign-in"
    fill_in 'user[email]', with: 'manager@example.test'
    fill_in 'user[password]', with: 'SecureTest123!@#'
    find('input[type=submit], button[type=submit]', match: :first).click
  end

  def captured(slug, callouts)
    DocsScreenshots.capture(page, slug, callouts:).map { |path| File.size(path) }
  end

  it 'captures the events list with series mentions' do
    visit "/#{locale}/events"
    callouts = [friday, saturday].map do |event|
      { selector: "#series_mention_event_#{event.id}", title: 'Series mention' }
    end

    expect(captured('event_series_list', callouts)).to all(be > 10_000)
  end

  it 'captures the series page' do
    visit "/#{locale}/events/#{series.slug}"

    expect(captured('event_series_show', [{ selector: "#sessions_event_#{series.id}", title: 'Dates as cards' }]))
      .to all(be > 10_000)
  end

  it 'captures a session page' do
    visit "/#{locale}/events/#{saturday.slug}"

    callouts = [{ selector: "#series_banner_event_#{saturday.id}", title: 'Series banner' }]

    expect(captured('event_series_session', callouts)).to all(be > 10_000)
  end

  it 'captures the cancel and delete panel' do
    sign_in_as_manager
    visit "/#{locale}/events/#{series.slug}"
    find("button[data-bs-target='#settlement_panel_event_#{series.id}']").click
    callouts = [{ selector: "#settlement_event_#{series.id}", title: 'Choose for the dates' }]

    expect(captured('event_series_settlement', callouts)).to all(be > 10_000)
  end
end
