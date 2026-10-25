# frozen_string_literal: true

require 'rails_helper'

# Date and time, then series, then location, in the show header, the About pane and the event card;
# in About the register link sits between privacy and the date and time.
RSpec.describe 'Event detail ordering', type: :request do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:series) do
    create(:better_together_event, series: true, starts_at: nil, ends_at: nil, privacy: 'public', name: 'Run')
  end
  let(:address) do
    { name: 'Rotary Arts Centre', line1: '5 Park Street', city_name: 'Corner Brook',
      state_province_name: 'Newfoundland and Labrador', country_name: 'Canada', postal_code: 'A2H 2Y8' }
  end
  let(:session) do
    create(:better_together_event, starts_at: 3.days.from_now, ends_at: 3.days.from_now + 1.hour, privacy: 'public',
                                   name: 'Night', session_of: series.identifier, address_spec: address.to_json,
                                   registration_url: 'https://tickets.example.test/night')
  end

  before do
    configure_host_platform
    session
    create(:better_together_event, starts_at: 4.days.from_now, ends_at: 4.days.from_now + 1.hour, privacy: 'public',
                                   name: 'Night', session_of: series.identifier)
    login('manager@example.test', 'SecureTest123!@#')
  end

  def in_order?(html, selectors)
    nodes = html.css(selectors.join(', ')).to_a
    selectors.map { |css| nodes.index(html.at_css(css)) }.each_cons(2).all? { |a, b| a && b && a < b }
  end

  it 'orders the show header' do
    get "/#{locale}/events/#{session.slug}"
    header = Nokogiri::HTML(response.body).at_css('.event-info-container')

    expect(in_order?(header, ['.event-datetime', '.event-series-banner', '.event-location'])).to be(true)
  end

  it 'orders the About pane' do
    get "/#{locale}/events/#{session.slug}"
    about = Nokogiri::HTML(response.body).at_css('#about')
    order = ['.fa-eye', '.fa-ticket', '.fa-calendar-alt', '.event-series-other-dates', '.event-location']

    expect(in_order?(about, order)).to be(true)
  end

  it 'orders the event card' do
    get "/#{locale}/events"
    card = Nokogiri::HTML(response.body).at_css("#event_#{session.id}, #event_card_#{session.id}") ||
           Nokogiri::HTML(response.body).at_css('.event-card')

    expect(in_order?(card, ['.event-datetime', '.event-series-mention', '.event-location'])).to be(true)
  end
end
