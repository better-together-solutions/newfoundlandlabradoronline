# frozen_string_literal: true

require 'rails_helper'

# Documentation screenshots for the community Events and Posts tabs (scoped indexes in turbo-frames) and the
# collapsible posts filters (desktop and mobile, plain and annotated).
#
#   RUN_DOCS_SCREENSHOTS=1 ./bin/dc-run bundle exec rspec spec/docs_screenshots/community_tabs_spec.rb
RSpec.describe 'Documentation screenshots for the community tabs', :js, type: :feature do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:community) { create(:better_together_community, privacy: 'public', name: 'Rotary Arts Centre') }

  def hosted_event(name, start)
    create(:better_together_event, platform:, name:, privacy: 'public', status: 'confirmed',
                                   starts_at: start, ends_at: start + 2.hours)
      .tap { |event| event.event_hosts.create!(host: community) }
  end

  def captured(slug, callouts, &)
    DocsScreenshots.capture(page, slug, callouts:, &).map { |path| File.size(path) }
  end

  before do
    skip 'set RUN_DOCS_SCREENSHOTS=1 to capture documentation screenshots' unless ENV['RUN_DOCS_SCREENSHOTS']

    configure_host_platform.update!(privacy: 'public')
    hosted_event('A Tribute to Black Sabbath', 2.days.from_now)
    hosted_event('Nutcrackers with Tina Randell', 9.days.from_now)
    create(:better_together_post, platform:, community:, privacy: 'public', published_at: 1.day.ago,
                                  title: 'Doors open for the winter season')
  end

  def open_tab(tab, path_suffix = '')
    visit "/#{locale}/c/#{community.slug}#{path_suffix}"
    find("##{tab}-tab").click
  end

  it 'captures the events tab, soonest first' do
    open_tab('events', '#events')
    callouts = [{ selector: '#community-events-list', title: 'Soonest first' }]

    expect(captured('community_events_tab', callouts)).to all(be > 10_000)
  end

  it 'captures the posts tab with its collapsible filters' do
    open_tab('posts')
    callouts = [{ selector: '#community-posts #posts-filter-sidebar', title: 'Filters collapse on small screens' }]

    expect(captured('community_posts_tab', callouts)).to all(be > 10_000)
  end
end
