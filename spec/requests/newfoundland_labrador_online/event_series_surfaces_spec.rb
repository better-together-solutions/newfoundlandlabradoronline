# frozen_string_literal: true

require 'rails_helper'

# Where a series and its sessions appear: the settlement Events tab and its past list show the sessions (the series is
# a "Part of" mention on each card), and the sitemap covers both the series page and every session page.
RSpec.describe 'Event series surfaces' do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:settlement) { create(:geography_settlement, identifier: 'cb-town', name: 'Cbtown') }
  let(:series) do
    create(:better_together_event, platform:, series: true, starts_at: nil, ends_at: nil, privacy: 'public',
                                   status: 'confirmed', name: 'Tribute Run')
  end
  let(:address) do
    { name: 'Rotary Arts Centre', line1: '5 Park Street', city_name: 'Corner Brook',
      state_province_name: 'Newfoundland and Labrador', country_name: 'Canada', postal_code: 'A2H 2Y8' }
  end

  def add_session(name, start)
    create(:better_together_event, platform:, name:, privacy: 'public', status: 'confirmed', starts_at: start,
                                   ends_at: start + 2.hours, session_of: series.identifier)
      .tap { |event| event.update!(settlement_identifier: 'cb-town') }
  end

  def series_links
    Nokogiri::HTML(response.body).css(%(a[href*="events/#{series.slug}"]))
  end

  before do
    configure_host_platform
    settlement
    series.update!(settlement_identifier: 'cb-town')
    add_session('Tribute Night Soon', 3.days.from_now)
    add_session('Tribute Night Gone', 3.days.ago)
  end

  it 'lists the upcoming session, not the series, in the settlement events list', :aggregate_failures do
    get "/#{locale}/events", params: { settlement: 'cb-town' }

    expect(response.body).to include('Tribute Night Soon')
    expect(series_links.size).to eq(1)
  end

  it 'lists the past session, not the series, in the settlement past list', :aggregate_failures do
    get "/#{locale}/events", params: { settlement: 'cb-town', past: '1' }

    expect(response.body).to include('Tribute Night Gone')
    expect(series_links.size).to eq(1)
  end

  it 'pins the sessions on the events map, not the series', :aggregate_failures do
    [series, *series.sessions].each { |event| event.update!(address_data: address.to_json) }
    records = BetterTogether::Geography::EventCollectionMap.records(BetterTogether::Event.where(platform:))

    expect(records.map(&:identifier)).to include(*series.sessions.map(&:identifier))
    expect(records.map(&:identifier)).not_to include(series.identifier)
  end

  it 'puts the series and its sessions in the sitemap scope' do
    listed = BetterTogether::Event.for_platform(platform).privacy_public

    expect(listed.pluck(:identifier)).to include(series.identifier, *series.sessions.map(&:identifier))
  end
end
