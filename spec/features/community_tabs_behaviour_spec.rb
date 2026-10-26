# frozen_string_literal: true

require 'rails_helper'

# The community tabs use the shared tabs controller: a click switches the pane and updates the URL hash without
# scrolling the page, and a hash in the URL opens its tab.
RSpec.describe 'Community tabs behaviour', :js, type: :feature do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:community) { create(:better_together_community, privacy: 'public', name: 'Tabs Group') }

  before { configure_host_platform.update!(privacy: 'public') }

  def scroll_down
    # Smooth scrolling would make scrollY lag behind the jump this guards against.
    page.execute_script("document.documentElement.style.scrollBehavior = 'auto'; " \
                        "document.body.style.minHeight = '4000px'; window.scrollTo(0, 120)")
    page.evaluate_script('window.scrollY').tap { |y| raise 'page is not scrollable' unless y.positive? }
  end

  it 'switches panes and updates the hash without scrolling', :aggregate_failures do
    visit "/#{locale}/c/#{community.slug}"
    before = scroll_down
    find('#events-tab').click

    expect(page).to have_css('#events.active.show')
    expect(page.evaluate_script('[window.location.hash, window.scrollY]')).to eq(['#events', before])
  end

  it 'opens the tab named in the URL hash' do
    visit "/#{locale}/c/#{community.slug}#posts"

    expect(page).to have_css('#posts.active.show')
  end
end
