# frozen_string_literal: true

require 'rails_helper'

# Documentation screenshots for the event map beside the tabs, the community map beside the tabs (with the events
# list sized to the narrow pane) and the community Contact tab (desktop and mobile, plain and annotated).
#
#   RUN_DOCS_SCREENSHOTS=1 ./bin/dc-run bundle exec rspec spec/docs_screenshots/show_layout_spec.rb
RSpec.describe 'Documentation screenshots for the show layouts', :js, type: :feature do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:community) do
    create(:better_together_community, privacy: 'public', name: 'Rotary Arts Centre',
                                       address_spec: address.to_json, contact_spec: contacts.to_json)
  end
  let(:event) do
    create(:better_together_event, platform:, name: 'A Tribute to Fleetwood Mac', privacy: 'public',
                                   status: 'confirmed', starts_at: 3.days.from_now,
                                   ends_at: 3.days.from_now + 2.hours, address_spec: address.to_json,
                                   description: '<div>Doors open at 7.</div>')
  end

  def address
    { name: 'Rotary Arts Centre', line1: '5 Park Street', city_name: 'Corner Brook', postal_code: 'A2H 2Y8',
      state_province_name: 'Newfoundland and Labrador', country_name: 'Canada' }
  end

  def contacts
    { phone_numbers: [{ number: '709-630-0012', label: 'Box office' }],
      email_addresses: [{ email: 'info@rotaryartscentre.ca', label: 'General enquiries' }] }
  end

  def captured(slug, callouts, &)
    DocsScreenshots.capture(page, slug, callouts:, &).map { |path| File.size(path) }
  end

  def geocode(record)
    BetterTogether::Address.find(record.location.location_id).update!(latitude: 48.9517, longitude: -57.9474)
  end

  before do
    skip 'set RUN_DOCS_SCREENSHOTS=1 to capture documentation screenshots' unless ENV['RUN_DOCS_SCREENSHOTS']

    configure_host_platform.update!(privacy: 'public')
    [event, create(:better_together_event, platform:, name: 'Nutcrackers with Tina Randell', privacy: 'public',
                                           status: 'confirmed', starts_at: 9.days.from_now,
                                           ends_at: 9.days.from_now + 2.hours)].each do |hosted|
      hosted.event_hosts.create!(host: community)
    end
    geocode(event)
    geocode(community)
  end

  it 'captures the event with its map beside the tabs' do
    visit "/#{locale}/events/#{event.slug}"
    callouts = [{ selector: '#event-map', title: 'Map beside the tabs' }]

    expect(captured('event_map_beside_tabs', callouts)).to all(be > 10_000)
  end

  it 'captures the events tab beside the community map' do
    visit "/#{locale}/c/#{community.slug}"
    find('#events-tab').click
    find('#community-events-list .entity-column', match: :first)
    callouts = [{ selector: '#community-map', title: 'Map' }, { selector: '#community-events-list', title: 'Cards' }]
    expect(captured('community_events_beside_map', callouts)).to all(be > 10_000)
  end

  it 'captures the contact tab' do
    visit "/#{locale}/c/#{community.slug}"
    find('#contact-tab').click
    find('#contact', text: '709-630-0012')
    callouts = [{ selector: '#contact', title: 'Contact details in their own tab' }]

    expect(captured('community_contact_tab', callouts)).to all(be > 10_000)
  end
end
