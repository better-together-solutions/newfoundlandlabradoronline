# frozen_string_literal: true

require 'rails_helper'

# A community located at a street address shows the place's name and address, CE's map for it, and the contact
# details it was given, each under its own label.
RSpec.describe 'Community page location and contacts' do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:community) { create(:better_together_community, privacy: 'public', name: 'Arts Centre') }
  let(:address) do
    { name: 'Rotary Arts Centre', line1: '5 Park Street', city_name: 'Corner Brook', postal_code: 'A2H 2Y8',
      country_name: 'Canada' }
  end
  let(:contacts) do
    { phone_numbers: [{ number: '709-630-0012', label: 'Box office' }],
      email_addresses: [{ email: 'info@rotaryartscentre.ca', label: 'General enquiries' }] }
  end

  before do
    configure_host_platform
    community.update!(address_data: address.to_json, contact_data: contacts.to_json)
  end

  def geocode_address
    place = BetterTogether::Address.find(community.location.location_id)
    place.assign_attributes(latitude: 48.9517, longitude: -57.9474)
    place.save!
  end

  def fetch_page
    get "/#{locale}/c/#{community.slug}"
  end

  it 'shows the place name, address and custom contact labels', :aggregate_failures do
    fetch_page

    expect(response.body).to include('id="community-location"', 'Rotary Arts Centre', '5 Park Street')
    expect(response.body).to include('Box office', '709-630-0012', 'General enquiries')
  end

  it 'puts the contact details in their own tab, not in About', :aggregate_failures do
    fetch_page
    doc = Nokogiri::HTML(response.body)

    expect(doc.at_css('a#contact-tab[href="#contact"]')).to be_present
    expect(doc.at_css('#contact').text).to include('Box office', '709-630-0012')
    expect(doc.at_css('#about').text).not_to include('709-630-0012')
  end

  it 'shows no map until the address has coordinates' do
    fetch_page

    expect(response.body).not_to include('id="community-map"')
  end

  it 'shows the community map once the address is geocoded' do
    geocode_address
    fetch_page

    expect(response.body).to include('id="community-map"')
  end
end
