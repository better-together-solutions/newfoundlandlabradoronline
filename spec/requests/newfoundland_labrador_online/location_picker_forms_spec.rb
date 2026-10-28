# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Location picker' do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }

  before { configure_host_platform }

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
