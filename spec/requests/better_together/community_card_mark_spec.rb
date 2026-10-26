# frozen_string_literal: true

require 'rails_helper'

# A community's card shows its logo, else its profile image (never both); with no cover the mark replaces the cover.
RSpec.describe 'Community card mark', type: :request do
  include RequestSpecHelper

  let(:cover) { Rails.root.join('spec/fixtures/covers/nl-ped-corner-brook.jpg') }
  let(:picture) { Rails.root.join('spec/fixtures/files/frame_with_exif.jpg') }

  def attach(community, name, path)
    community.public_send(name).attach(io: File.open(path), filename: path.basename.to_s, content_type: 'image/jpeg')
  end

  def community_with(images)
    create(:better_together_community, privacy: 'public').tap do |community|
      images.each { |name, path| attach(community, name, path) }
    end
  end

  def mark_ids(*communities)
    get better_together.communities_path(locale: I18n.default_locale)
    communities.map { |community| response.body.include?("id=\"card_mark_community_#{community.id}\"") }
  end

  before { configure_host_platform }

  it 'shows the logo as a tile over the cover when there is one', :aggregate_failures do
    community = community_with(cover_image: cover, logo: picture, profile_image: picture)

    expect(mark_ids(community)).to eq([true])
    expect(response.body.scan("card_mark_community_#{community.id}").size).to eq(1)
    expect(response.body).to include('community-card-mark community-card-mark--cover')
  end

  it 'falls back to the profile image, and shows nothing when there is neither' do
    with_profile = community_with(cover_image: cover, profile_image: picture)
    bare = community_with(cover_image: cover)

    expect(mark_ids(with_profile, bare)).to eq([true, false])
  end

  it 'replaces the cover with the mark when the community has no cover', :aggregate_failures do
    community = community_with(logo: picture)
    mark_ids(community)

    expect(response.body).to include('community-card--mark-only')
    expect(response.body).not_to include('community-card-mark--cover')
  end

  describe 'community page header' do
    def show_body(community)
      get better_together.community_path(community, locale: I18n.default_locale)
      response.body
    end

    it 'shows the logo tile in the profile image position', :aggregate_failures do
      body = show_body(community_with(cover_image: cover, logo: picture, profile_image: picture))

      expect(body).to include('community-logo-tile')
      expect(body).not_to include('community-header-mark')
    end

    it 'keeps the round profile image when there is no logo', :aggregate_failures do
      body = show_body(community_with(cover_image: cover, profile_image: picture))

      expect(body).not_to include('community-logo-tile')
      expect(body).to include('profile-image-wrapper')
    end

    it 'shows the mark large in place of a missing cover, without a second mark', :aggregate_failures do
      body = show_body(community_with(logo: picture))

      expect(body).to include('community-header-mark')
      expect(body).not_to include('community-logo-tile')
      expect(body).not_to include('profile-image-wrapper')
    end
  end
end
