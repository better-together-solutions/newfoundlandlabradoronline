# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::LocationInterface, '#address_spec=' do
  include RequestSpecHelper

  before { configure_host_platform }

  let(:spec_json) do
    { line1: '5 Park Street', city_name: 'Corner Brook', state_province_name: 'Newfoundland and Labrador',
      postal_code: 'A2H 2W9', country_name: 'Canada' }.to_json
  end

  let(:community) { build(:better_together_community) }

  it 'locates the record at a new public address', :aggregate_failures do
    community.address_spec = spec_json
    community.save!

    address = community.reload.location.location
    expect(address).to be_a(BetterTogether::Address)
    expect(address).to have_attributes(line1: '5 Park Street', city_name: 'Corner Brook', privacy: 'public')
  end

  it 'names the place when the spec carries a name', :aggregate_failures do
    community.address_spec = JSON.parse(spec_json).merge('name' => 'Rotary Arts Centre').to_json
    community.save!

    expect(community.reload.location.name).to eq('Rotary Arts Centre')
    expect(community.location.location).to have_attributes(line1: '5 Park Street')
  end

  it 'reuses an existing address for the next record', :aggregate_failures do
    community.update!(address_spec: spec_json)
    event = create(:better_together_event, address_spec: spec_json)

    expect(event.reload.location.location).to eq(community.location.location)
    expect(BetterTogether::Address.where(line1: '5 Park Street').count).to eq(1)
  end

  it 'clears the location when blank', :aggregate_failures do
    community.address_spec = spec_json
    community.save!

    community.update!(address_spec: nil)

    expect(community.reload.location).to be_nil
  end

  it 'rejects an address without line1', :aggregate_failures do
    community.address_spec = { city_name: 'Corner Brook' }.to_json

    expect(community).not_to be_valid
    expect(community.errors[:address_spec]).to be_present
  end

  it 'rejects invalid JSON', :aggregate_failures do
    community.address_spec = '{nope'

    expect(community).not_to be_valid
    expect(community.errors[:address_spec]).to be_present
  end

  it 'puts an event at a placed address into the settlement events list', :aggregate_failures do
    settlement = create(:geography_settlement, identifier: 'cb-town', name: 'Cbtown')
    event = create(:better_together_event, starts_at: 2.days.from_now, ends_at: 2.days.from_now + 1.hour)
    event.update!(address_spec: spec_json)
    BetterTogether::Geography::LocatableLocation.create!(locatable: event.location.location, location: settlement)

    expect(BetterTogether::Event.located_in(settlement)).to include(event)
  end
end
