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
end
