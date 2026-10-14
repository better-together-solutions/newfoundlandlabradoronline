# frozen_string_literal: true

require 'rails_helper'
require 'support/locatable_record_examples'

RSpec.describe NewfoundlandLabradorOnline::Locatable do
  include RequestSpecHelper

  before { configure_host_platform }

  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform) }
  let(:person) { create(:better_together_person) }

  describe 'a post' do
    let(:record) { create(:better_together_post, platform:, privacy: 'private', author: person) }

    it_behaves_like 'a locatable record'
  end

  describe 'a community' do
    let(:record) { create(:better_together_community, privacy: 'private') }

    it_behaves_like 'a locatable record'
  end

  describe 'an event' do
    let(:record) { create(:event, privacy: 'private') }

    it_behaves_like 'a locatable record'

    it 'keeps CE locatable one behaviour (the same location association)' do
      expect(BetterTogether::Event.included_modules).to include(BetterTogether::Geography::Locatable::One)
    end
  end

  describe 'inheriting a location from the community' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let!(:settlement) { create(:geography_settlement, identifier: 'cb-test') }
    let!(:elsewhere) { create(:geography_settlement, identifier: 'elsewhere-test') }
    let(:community) do
      create(:better_together_community, privacy: 'private').tap { |c| c.update!(settlement_identifier: 'cb-test') }
    end
    let(:post) { create(:better_together_post, platform:, privacy: 'private', author: person, community:) }

    it 'lets a post without a location take its community location', :aggregate_failures do
      expect(post.effective_location).to eq(settlement)
      expect(BetterTogether::Post.located_in(settlement)).to include(post)
    end

    it 'lets the posts own location win over its community', :aggregate_failures do
      post.update!(settlement_identifier: 'elsewhere-test', privacy: 'private')

      expect(post.effective_location).to eq(elsewhere)
      expect(BetterTogether::Post.located_in(settlement)).not_to include(post)
      expect(BetterTogether::Post.located_in(elsewhere)).to include(post)
    end

    it 'does not inherit when the post has a location that is only free text', :aggregate_failures do
      BetterTogether::Geography::LocatableLocation.create!(locatable: post, name: 'Somewhere nice')

      expect(post.effective_location).to be_nil
      expect(BetterTogether::Post.located_in(settlement)).not_to include(post)
    end

    context 'when the community sits at an address within the settlement' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      let(:locations) { BetterTogether::Geography::LocatableLocation }
      let(:address) { create(:better_together_address) }
      let(:other) { create(:better_together_community, privacy: 'private') }

      before do
        locations.create!(locatable: address, location: settlement)
        locations.create!(locatable: other, location: address)
      end

      it 'finds its posts' do
        inherited = create(:better_together_post, platform:, privacy: 'private', author: person, community: other)

        expect(BetterTogether::Post.located_in(settlement)).to include(inherited)
      end
    end

    it 'does not take the community location for a community that has none' do
      lonely = create(:better_together_post, platform:, privacy: 'private', author: person,
                                             community: create(:better_together_community, privacy: 'private'))

      expect(BetterTogether::Post.located_in(settlement)).not_to include(lonely)
    end
  end

  describe 'permitted attributes' do
    it 'allows nested location attributes on posts and communities', :aggregate_failures do
      [BetterTogether::Post, BetterTogether::Community].each do |model|
        expect(model.permitted_attributes.flat_map { |a| a.is_a?(Hash) ? a.keys : a }).to include(:location_attributes)
      end
    end
  end

  describe 'the registry' do
    it 'notes the Joatu models as pending without wiring them', :aggregate_failures do
      registry = NewfoundlandLabradorOnline::LocatableModels
      expect(registry::PENDING).to eq(%w[BetterTogether::Joatu::Offer BetterTogether::Joatu::Request])
      expect(registry::ONBOARDED.keys & registry::PENDING).to be_empty
    end
  end
end
