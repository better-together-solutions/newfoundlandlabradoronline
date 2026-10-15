# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Settlement posts' do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:person) { BetterTogether::User.find_by(email: 'manager@example.test').person }
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:settlement) { create(:geography_settlement, identifier: 'cb-town', name: 'Cbtown') }
  let(:community) { create(:better_together_community, privacy: 'public', identifier: 'cb-online') }

  def make_post(title, **attrs)
    create(:better_together_post, platform:, privacy: 'public', author: person, title:, published_at: 1.hour.ago,
                                  **attrs)
  end

  before do
    configure_host_platform
    settlement
  end

  describe 'GET /posts?settlement=' do
    before do
      make_post('Direct post').update!(settlement_identifier: 'cb-town')
      make_post('Elsewhere post')
    end

    it 'lists only the posts located at the settlement, once each', :aggregate_failures do
      get "/#{locale}/posts", params: { settlement: 'cb-town' }

      expect(response).to have_http_status(:ok)
      expect(response.body.scan('Direct post').size).to be >= 1
      expect(response.body).not_to include('Elsewhere post')
    end

    it 'wraps the list in the turbo frame the settlement page embeds', :aggregate_failures do
      get "/#{locale}/posts", params: { settlement: 'cb-town' }

      expect(response.body).to include('<turbo-frame id="settlement-posts"')
      expect(response.body).to include('value="cb-town" type="hidden" name="settlement"')
    end

    it 'leaves the unscoped posts index alone', :aggregate_failures do
      get "/#{locale}/posts"

      expect(response.body).to include('Direct post', 'Elsewhere post')
      expect(response.body).not_to include('turbo-frame id="settlement-posts"')
    end

    it 'answers an unknown settlement with not found' do
      get "/#{locale}/posts", params: { settlement: 'nowhere' }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'a post inheriting its communitys location' do
    it 'appears in the settlement list' do
      community.update!(settlement_identifier: 'cb-town')
      make_post('Inherited post', community:)

      get "/#{locale}/posts", params: { settlement: 'cb-town' }

      expect(response.body).to include('Inherited post')
    end
  end

  describe 'the settlement page' do
    before { community.update!(settlement_identifier: 'cb-town') }

    it 'has a Posts tab that lazy loads the scoped list and lists located communities', :aggregate_failures do
      get "/#{locale}/g/settlements/#{settlement.slug}"

      expect(response.body).to include('id="posts-tab"')
      expect(response.body).to include('settlement=cb-town')
      expect(response.body).to include('id="communities-tab"')
    end

    it 'shows the located communities as cards in their own tab', :aggregate_failures do
      get "/#{locale}/g/settlements/#{settlement.slug}"

      pane = response.body[%r{<div id="communities".*?</div>\s*</div>}m]
      expect(pane).to include(community.name)
      expect(response.body).not_to include('settlement-communities-heading')
    end

    it 'renders the map when the settlement has coordinates' do
      space = BetterTogether::Geography::Space.create!(latitude: 48.95, longitude: -57.95)
      BetterTogether::Geography::GeospatialSpace.create!(geospatial: settlement, space:)

      get "/#{locale}/g/settlements/#{settlement.slug}"

      expect(response.body).to include('data-controller="better_together--map"')
    end
  end

  describe 'the community page' do
    it 'links to the settlement it is located in' do
      community.update!(settlement_identifier: 'cb-town')

      get "/#{locale}/c/#{community.slug}"

      expect(response.body).to include('Cbtown')
    end
  end
end
