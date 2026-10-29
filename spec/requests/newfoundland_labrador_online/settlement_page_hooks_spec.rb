# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Settlement page host hooks' do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:settlement) { create(:geography_settlement, identifier: 'hooked-town', name: 'Hookedtown') }
  let(:body) { response.body }

  before { configure_host_platform }

  context 'when the settlement has a map space' do
    before do
      space = BetterTogether::Geography::Space.create!(latitude: 48.95, longitude: -57.95)
      BetterTogether::Geography::GeospatialSpace.create!(geospatial: settlement, space:)
      get "/#{locale}/g/settlements/#{settlement.slug}"
    end

    it 'puts the map above the tabs' do
      expect(body.index('id="settlement-map"')).to be < body.index('id="settlement-tabbed-section"')
    end

    it 'keeps the Posts and Events tabs from CE' do
      expect(body).to include('id="posts-tab"', 'id="events-tab"')
    end
  end
end
