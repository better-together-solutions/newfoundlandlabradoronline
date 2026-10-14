# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::SettlementMap do
  include RequestSpecHelper

  let(:settlement) { create(:geography_settlement, identifier: 'map-town', name: 'Maptown') }
  let(:scope_for) { lambda(&:all) }
  let(:map) { described_class.new(settlement, scope_for:, url_for: ->(record) { "/x/#{record.id}" }) }
  let(:locations) { BetterTogether::Geography::LocatableLocation }

  before do
    configure_host_platform
    settlement.space&.update!(latitude: 48.95, longitude: -57.95)
  end

  def geocoded_address
    create(:better_together_address).tap do |address|
      address.space.update!(latitude: 48.96, longitude: -57.94)
      locations.create!(locatable: address, location: settlement)
    end
  end

  def host_post(location)
    platform = BetterTogether::Platform.find_by(host: true)
    create(:better_together_post, platform:, privacy: 'public', published_at: 1.hour.ago,
                                  author: BetterTogether::User.first.person).tap { |p| locations.create!(locatable: p, location:) }
  end

  it 'describes every registered type with its colour and icon', :aggregate_failures do
    expect(map.types.pluck(:key)).to match_array(NewfoundlandLabradorOnline::LocatableModels.models.map { |m|
      m.base_class.name
    })
    expect(map.types).to all(include(:label, :color, :icon))
  end

  it 'has the settlement pin from its geocoded space' do
    expect(map.pin).to include(name: 'Maptown', lat: 48.95, lng: -57.95)
  end

  it 'has no boundary when none is stored' do
    expect(map.boundary).to be_nil
  end

  it 'includes records located at a geocoded address inside the settlement', :aggregate_failures do
    post = host_post(geocoded_address)

    expect(map.items).to contain_exactly(a_hash_including(type: 'BetterTogether::Post', title: post.title, lat: 48.96,
                                                          lng: -57.94))
  end

  it 'leaves out records located at the settlement itself, which the pin already shows' do
    host_post(settlement)

    expect(map.items).to be_empty
  end

  it 'only uses the records the scope allows' do
    host_post(geocoded_address)
    nothing = described_class.new(settlement, scope_for: lambda(&:none), url_for: lambda(&:id))

    expect(nothing.items).to be_empty
  end
end
