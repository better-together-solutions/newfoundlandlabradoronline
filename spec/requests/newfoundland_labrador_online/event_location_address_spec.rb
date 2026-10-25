# frozen_string_literal: true

require 'rails_helper'

# A named place at a street address shows both on the event page, so visitors know where to go.
RSpec.describe 'Event page location' do
  include RequestSpecHelper

  let(:event) do
    create(:better_together_event, name: 'Tribute night', privacy: 'public', starts_at: 3.days.from_now,
                                   ends_at: 3.days.from_now + 2.hours)
  end

  before do
    configure_host_platform
    event.update!(address_spec: { name: 'Rotary Arts Centre', line1: '5 Park Street', city_name: 'Corner Brook',
                                  postal_code: 'A2H 2Y8', country_name: 'Canada' }.to_json)
  end

  it 'prints the place name and its street address', :aggregate_failures do
    get "/#{I18n.default_locale}/events/#{event.slug}"

    expect(response.body).to include('Rotary Arts Centre')
    expect(response.body).to include('5 Park Street')
  end
end
