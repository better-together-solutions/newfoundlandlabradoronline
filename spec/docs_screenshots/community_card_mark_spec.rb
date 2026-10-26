# frozen_string_literal: true

require 'rails_helper'

# Documentation screenshots for the logo or profile image on community cards (desktop and mobile).
#
#   RUN_DOCS_SCREENSHOTS=1 ./bin/dc-run bundle exec rspec spec/docs_screenshots/community_card_mark_spec.rb
#
# Assets land in docs/screenshots/{desktop,mobile}/. Open each PNG and confirm the target is in frame.
RSpec.describe 'Documentation screenshots for community card marks', :js, type: :feature do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:cover) { Rails.root.join('spec/fixtures/covers/nl-ped-corner-brook.jpg') }
  let(:picture) { Rails.root.join('spec/fixtures/covers/nl-ped-st-john-s-centre.jpg') }

  def community_with(name, images)
    create(:better_together_community, name:, privacy: 'public').tap do |community|
      images.each do |attachment, path|
        community.public_send(attachment).attach(io: File.open(path), filename: path.basename.to_s,
                                                 content_type: 'image/jpeg')
      end
    end
  end

  def captured(over_cover, in_place)
    callouts = [{ selector: "#card_mark_community_#{over_cover.id}", title: 'Logo over the cover' },
                { selector: "#card_mark_community_#{in_place.id}", title: 'Mark replaces a missing cover' }]
    DocsScreenshots.capture(page, 'community_card_mark', callouts:).map { |path| File.size(path) }
  end

  before do
    skip 'set RUN_DOCS_SCREENSHOTS=1 to capture documentation screenshots' unless ENV['RUN_DOCS_SCREENSHOTS']

    configure_host_platform.update!(privacy: 'public')
  end

  it 'captures community cards with a logo tile on the cover and with the mark in place of the cover' do
    over_cover = community_with('Rotary Arts Centre', cover_image: cover, logo: picture)
    in_place = community_with('Corner Brook Folk Society', profile_image: picture)
    visit "/#{locale}/communities"

    expect(captured(over_cover, in_place)).to all(be > 10_000)
  end

  def capture_header(community, slug, selector)
    visit "/#{locale}/c/#{community.slug}"
    DocsScreenshots.capture(page, slug, callouts: [{ selector:, title: 'Logo' }])
  end

  it 'captures the community page header with a logo tile and with the mark in place of the cover' do
    with_cover = community_with('Rotary Arts Centre', cover_image: cover, logo: picture)
    no_cover = community_with('Corner Brook Folk Society', logo: picture)
    shots = [capture_header(with_cover, 'community_show_logo', "#logo_tile_community_#{with_cover.id}"),
             capture_header(no_cover, 'community_show_logo_no_cover', "#header_mark_community_#{no_cover.id}")]

    expect(shots.flatten.map { |path| File.size(path) }).to all(be > 10_000)
  end
end
