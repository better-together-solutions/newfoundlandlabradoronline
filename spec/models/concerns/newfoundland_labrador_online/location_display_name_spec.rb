# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::LocationDisplayName do
  let(:address) do
    build(:better_together_address, line1: '5 Park Street', city_name: 'Corner Brook', postal_code: 'A2H 2Y8',
                                    country_name: 'Canada')
  end

  it 'adds the street address to the name of a place at an address', :aggregate_failures do
    place = BetterTogether::Geography::LocatableLocation.new(name: 'Rotary Arts Centre', location: address)

    expect(place.display_name).to start_with('Rotary Arts Centre, 5 Park Street, Corner Brook')
    expect(place.display_name).to end_with('A2H 2Y8, Canada')
  end

  it 'leaves a free text place and an unnamed address as they were', :aggregate_failures do
    expect(BetterTogether::Geography::LocatableLocation.new(name: 'The wharf').display_name).to eq('The wharf')
    expect(BetterTogether::Geography::LocatableLocation.new(location: address).display_name).to eq(address.to_s)
  end
end
