# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::VideoCategories do
  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform) }

  it 'seeds idempotently' do
    described_class.seed!(platform:)

    expect { described_class.seed!(platform:) }.not_to change(BetterTogether::Category, :count)
  end

  it 'adds the shorts category for portrait videos only', :aggregate_failures do
    portrait = described_class.identifiers_for(kind: 'daily', orientation: 'portrait')
    landscape = described_class.identifiers_for(kind: 'monthly', orientation: 'landscape')

    expect(portrait).to eq(%w[timelapse daily-timelapse shorts])
    expect(landscape).to eq(%w[timelapse monthly-timelapse])
  end
end
