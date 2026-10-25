# frozen_string_literal: true

require 'rails_helper'

# The event and community maps sit in a column beside the tabs like the partner page; rich-text descriptions
# are blocks, so they render in a div, never a p.
RSpec.describe 'Event and community show layout' do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:address) do
    { name: 'Rotary Arts Centre', line1: '5 Park Street', city_name: 'Corner Brook', postal_code: 'A2H 2Y8',
      state_province_name: 'Newfoundland and Labrador', country_name: 'Canada' }
  end
  let(:community) do
    create(:better_together_community, privacy: 'public', name: 'Arts Centre', address_spec: address.to_json)
  end
  let(:event) do
    create(:better_together_event, privacy: 'public', name: 'Night', starts_at: 3.days.from_now,
                                   ends_at: 3.days.from_now + 1.hour, address_spec: address.to_json,
                                   description: '<div>Doors at <strong>7</strong></div>')
  end

  before do
    configure_host_platform
    BetterTogether::EventHost.create!(event:, host: community)
  end

  def geocode(record)
    place = BetterTogether::Address.find(record.location.location_id)
    place.update!(latitude: 48.9517, longitude: -57.9474)
  end

  def page_for(path)
    get path
    Nokogiri::HTML(response.body)
  end

  describe 'event' do
    before { geocode(event) }

    it 'places the map in a column beside the tabs', :aggregate_failures do
      doc = page_for("/#{locale}/events/#{event.slug}")

      expect(doc.at_css('.row > .col-xl-4#event-map')).to be_present
      expect(doc.at_css('#about #event-map')).to be_nil
    end

    it 'renders the description in a div', :aggregate_failures do
      doc = page_for("/#{locale}/events/#{event.slug}")

      expect(doc.at_css('div#event-description')).to be_present
      expect(doc.at_css('p#event-description')).to be_nil
    end
  end

  describe 'community' do
    before { geocode(community) }

    it 'places the map in a column beside the tabs', :aggregate_failures do
      doc = page_for("/#{locale}/c/#{community.slug}")

      expect(doc.at_css('.row > .col-xl-4#community-map')).to be_present
      expect(doc.at_css('#about #community-map')).to be_nil
    end

    it 'renders the description in a div', :aggregate_failures do
      doc = page_for("/#{locale}/c/#{community.slug}")

      expect(doc.at_css('div#community-description')).to be_present
      expect(doc.at_css('p#community-description')).to be_nil
    end
  end
end
