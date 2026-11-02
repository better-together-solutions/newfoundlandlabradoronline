# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Weather::LocationLoader do
  include RequestSpecHelper

  before do
    configure_host_platform
    allow(BetterTogether::Weather::RefreshLocationJob).to receive(:perform_later)
    allow(BetterTogether::Weather::BackfillLocationJob).to receive(:perform_later)
  end

  let!(:settlement) do
    create(:geography_settlement, name: 'Corner Brook', identifier: 'corner-brook')
  end
  let(:config) do
    { 'environment_canada' => {
      'adapter' => 'environment_canada', 'enabled' => true, 'config' => { 'language' => 'en' },
      'locations' => {
        'corner-brook' => { 'external_ref' => 'NL/s0000221', 'observation_station_ref' => '8401298',
                            'time_zone' => 'America/St_Johns' },
        'nowhere' => { 'external_ref' => 'NL/s0', 'time_zone' => 'America/St_Johns' }
      }
    } }
  end

  def run(apply:)
    described_class.new(config:, apply:).call
  end

  it 'writes nothing on a dry run', :aggregate_failures do
    result = run(apply: false)

    expect(result.created).to eq(['environment_canada:corner-brook'])
    expect(BetterTogether::Weather::Location.count).to eq(0)
  end

  it 'reports settlements it cannot find' do
    expect(run(apply: false).missing_settlements).to eq(['nowhere'])
  end

  it 'creates the source and location when applied, and is idempotent', :aggregate_failures do
    run(apply: true)
    second = run(apply: true)

    expect(BetterTogether::Weather::Location.where(settlement:).count).to eq(1)
    expect(second.existing).to eq(['environment_canada:corner-brook'])
  end
end
