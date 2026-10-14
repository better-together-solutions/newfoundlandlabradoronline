# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::VideoCategoryBuilder do
  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform) }

  it 'seeds all categories idempotently', :aggregate_failures do
    expect(described_class.seed_data(platform:).map(&:identifier)).to match_array(described_class::DEFINITIONS.keys)
    expect { described_class.seed_data(platform:) }.not_to change(BetterTogether::Category, :count)
  end

  it 'seeds through the CE Builder entry point' do
    expect { described_class.build }.to change(BetterTogether::Category, :count).by(described_class::DEFINITIONS.size)
  end

  it 'adds the shorts category for portrait videos only', :aggregate_failures do
    portrait = described_class.identifiers_for(kind: 'daily', orientation: 'portrait')
    landscape = described_class.identifiers_for(kind: 'monthly', orientation: 'landscape')

    expect(portrait).to eq(%w[timelapse daily-timelapse sky shorts])
    expect(landscape).to eq(%w[timelapse monthly-timelapse sky])
  end

  describe 'a re-run after changes' do
    before do
      described_class.seed_data(platform:)
      sky = BetterTogether::Category.find_by!(identifier: 'sky', platform:)
      Mobility.with_locale(:en) { sky.update!(name: 'Sky and weather') }
      BetterTogether::Category.where(identifier: 'shorts', platform:).delete_all
    end

    it 'adds only the missing category' do
      expect { described_class.seed_data(platform:) }.to change(BetterTogether::Category, :count).by(1)
    end

    it 'leaves existing categories unchanged' do
      described_class.seed_data(platform:)
      sky = BetterTogether::Category.find_by!(identifier: 'sky', platform:)

      expect(Mobility.with_locale(:en) { sky.name }).to eq('Sky and weather')
    end
  end

  it 'seeds the sky category', :aggregate_failures do
    described_class.seed_data(platform:)

    expect(BetterTogether::Category.find_by(identifier: 'sky', platform:)).to be_present
  end

  it 'refuses to clear protected categories' do
    expect { described_class.clear_existing }.to raise_error(NotImplementedError)
  end
end
