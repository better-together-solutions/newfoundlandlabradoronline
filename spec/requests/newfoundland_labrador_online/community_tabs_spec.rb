# frozen_string_literal: true

require 'rails_helper'

# The community page Posts and Events tabs embed the posts and events indexes scoped to the community
# (?community_id=), like the settlement page: the index's cards, filters, ordering (soonest first) and paging.
RSpec.describe 'Community tabs' do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:community) { create(:better_together_community, privacy: 'public', name: 'Hosting Group') }

  def hosted_event(name, start, **attrs)
    create(:better_together_event, platform:, name:, privacy: 'public', status: 'confirmed',
                                   starts_at: start, ends_at: start + 2.hours, **attrs)
      .tap { |event| event.event_hosts.create!(host: community) }
  end

  before do
    configure_host_platform
    hosted_event('Later show', 9.days.from_now)
    hosted_event('Sooner show', 2.days.from_now)
    hosted_event('Private show', 3.days.from_now, privacy: 'private')
    create(:better_together_event, platform:, name: 'Other group show', privacy: 'public', status: 'confirmed',
                                   starts_at: 4.days.from_now, ends_at: 4.days.from_now + 2.hours)
  end

  it 'embeds both scoped indexes in lazy turbo-frames', :aggregate_failures do
    get "/#{locale}/c/#{community.slug}"

    expect(response.body).to include('id="community-events"', "/#{locale}/events?community_id=#{community.slug}",
                                     'id="community-posts"', "/#{locale}/posts?community_id=#{community.slug}")
  end

  describe 'headings inside the frames' do
    def headings(path, params)
      get path, params: params
      Nokogiri::HTML(response.body).css('turbo-frame#community-events h1, turbo-frame#community-events h2, ' \
                                        'turbo-frame#community-posts h1, turbo-frame#community-posts h2')
              .map(&:name).uniq
    end

    it 'uses h2 so the community page keeps its single h1', :aggregate_failures do
      expect(headings("/#{locale}/events", community_id: community.slug)).to eq(['h2'])
      expect(headings("/#{locale}/posts", community_id: community.slug)).to eq(['h2'])
    end

    it 'keeps the h1 on the unscoped index' do
      get "/#{locale}/events"

      expect(Nokogiri::HTML(response.body).css('h1').size).to eq(1)
    end
  end

  describe 'GET /events?community_id=' do
    before { get "/#{locale}/events", params: { community_id: community.slug } }

    it 'lists only the public events the community hosts', :aggregate_failures do
      expect(response.body).to include('Sooner show', 'Later show', 'events-filter-sidebar')
      expect(response.body).not_to include('Private show', 'Other group show')
    end

    it 'orders the soonest first' do
      expect(response.body.index('Sooner show')).to be < response.body.index('Later show')
    end

    it 'keeps the scope and frame in the filter form', :aggregate_failures do
      expect(response.body).to include('name="community_id"', 'data-turbo-frame="community-events"')
    end
  end

  describe 'GET /posts?community_id=' do
    before { get "/#{locale}/posts", params: { community_id: community.slug } }

    it 'sits in the community frame with the filter form inside it', :aggregate_failures do
      expect(response.body).to include('turbo-frame id="community-posts"', 'data-turbo-frame="community-posts"')
    end

    it 'collapses the filters on small screens like the events index', :aggregate_failures do
      expect(response.body).to include('id="posts-filter-toggle"', 'id="posts-filter-sidebar"', 'collapse d-lg-block')
    end
  end
end
