# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::PageResourceExtension do
  let(:resource) { BetterTogether::Api::V1::PageResource }
  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform) }

  it 'accepts category identifiers on create and update', :aggregate_failures do
    expect(resource.creatable_fields({})).to include(:category_identifiers)
    expect(resource.updatable_fields({})).to include(:category_identifiers)
  end

  describe 'Page#category_identifiers=' do
    let(:page) { build(:better_together_page, platform:, privacy: 'private') }

    before { NewfoundlandLabradorOnline::VideoCategoryBuilder.seed_data(platform:) }

    it 'files the page under categories by identifier', :aggregate_failures do
      page.category_identifiers = %w[ships]
      page.save!

      expect(page.reload.category_identifiers).to eq(%w[ships])
    end

    it 'is invalid when an identifier is unknown', :aggregate_failures do
      page.category_identifiers = %w[ships nope]

      expect(page).not_to be_valid
      expect(page.errors[:base].join).to include('nope')
    end
  end
end
