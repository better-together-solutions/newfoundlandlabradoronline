# frozen_string_literal: true

require 'rails_helper'

# Documentation screenshots for a community's logo on event host mentions, community chips and the host picker.
#
#   RUN_DOCS_SCREENSHOTS=1 ./bin/dc-run bundle exec rspec spec/docs_screenshots/community_host_marks_spec.rb
#
# Assets land in docs/screenshots/{desktop,mobile}/. Open each PNG and confirm the target is in frame.
RSpec.describe 'Documentation screenshots for community host marks', :js, type: :feature do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:logo) { Rails.root.join('spec/fixtures/covers/nl-ped-st-john-s-centre.jpg') }
  let(:community) do
    create(:better_together_community, name: 'Rotary Arts Centre', privacy: 'public').tap do |record|
      record.logo.attach(io: File.open(logo), filename: 'logo.jpg', content_type: 'image/jpeg')
    end
  end
  let(:event) do
    create(:better_together_event, name: 'A Tribute to Fleetwood Mac', privacy: 'public',
                                   starts_at: 3.days.from_now, ends_at: 3.days.from_now + 2.hours,
                                   event_hosts_attributes: [{ host_type: 'BetterTogether::Community',
                                                              host_id: community.id }])
  end

  before do
    skip 'set RUN_DOCS_SCREENSHOTS=1 to capture documentation screenshots' unless ENV['RUN_DOCS_SCREENSHOTS']

    configure_host_platform.update!(privacy: 'public')
  end

  def sign_in_as_manager
    visit "/#{locale}/users/sign-in"
    fill_in 'user[email]', with: 'manager@example.test'
    fill_in 'user[password]', with: 'SecureTest123!@#'
    find('input[type=submit], button[type=submit]', match: :first).click
  end

  def captured(slug, selector, title)
    DocsScreenshots.capture(page, slug, callouts: [{ selector:, title: }]).map { |path| File.size(path) }
  end

  it 'captures the host mention on an event card' do
    event
    visit "/#{locale}/events"

    expect(captured('community_host_mention', '.event-hosts', 'Host mention')).to all(be > 10_000)
  end

  it 'captures the community chip on a post card' do
    create(:better_together_post, community:, privacy: 'public', published_at: 1.day.ago)
    visit "/#{locale}/posts"

    expect(captured('community_chip_logo', '.community-chip', 'Community chip')).to all(be > 10_000)
  end

  it 'captures the host picker' do
    event
    sign_in_as_manager
    visit "/#{locale}/events/#{event.slug}/edit"
    find('.nav-link, [role=tab], a, button', text: 'Hosts', match: :first).click

    expect(captured('community_host_picker', '.community-mark-tile', 'Host logo')).to all(be > 10_000)
  end
end
