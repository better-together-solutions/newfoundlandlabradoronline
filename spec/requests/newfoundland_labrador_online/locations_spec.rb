# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Location picker' do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:settlement) { create(:geography_settlement, identifier: 'picker-town', name: 'Pickertown') }

  before do
    configure_host_platform
    settlement
  end

  describe 'GET /:locale/locations/available' do
    it 'does not serve signed-out visitors' do
      get "/#{locale}/locations/available"

      expect(response).not_to have_http_status(:ok)
    end

    context 'when signed in' do
      before { login('manager@example.test', 'SecureTest123!@#') }

      it 'lists matching places across types with a typed value', :aggregate_failures do
        get "/#{locale}/locations/available", params: { search: 'Pickertown' }

        expect(response).to have_http_status(:ok)
        typed_value = "#{settlement.class.name}:#{settlement.id}"
        expect(response.parsed_body).to include(a_hash_including('value' => typed_value))
      end

      it 'lists one type as bare ids' do
        get "/#{locale}/locations/available", params: { location_type: settlement.class.name, search: 'Pickertown' }

        expect(response.parsed_body).to include(a_hash_including('value' => settlement.id))
      end

      it 'rejects a type that is not placeable' do
        get "/#{locale}/locations/available", params: { location_type: 'BetterTogether::Person' }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'the post form' do
    before { login('manager@example.test', 'SecureTest123!@#') }

    it 'renders the shared picker' do
      get "/#{locale}/posts/new"

      expect(response.body).to include('id="post_location_picker"')
    end
  end

  describe 'the community form' do
    before { login('manager@example.test', 'SecureTest123!@#') }

    it 'renders the location tab with the shared picker', :aggregate_failures do
      get "/#{locale}/communities/new"

      expect(response.body).to include('id="community-location-tab"')
      expect(response.body).to include('id="community_location_picker"')
    end
  end
end
