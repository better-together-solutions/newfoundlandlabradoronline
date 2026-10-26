# frozen_string_literal: true

require 'rails_helper'

# A community's logo (else profile image) shows the same way on host mentions, chips and the host picker.
RSpec.describe 'Community marks on hosts, chips and the host picker', type: :request do
  include RequestSpecHelper

  let(:picture) { Rails.root.join('spec/fixtures/files/frame_with_exif.jpg') }

  def community_with(*attachments)
    create(:better_together_community, privacy: 'public').tap do |community|
      attachments.each do |name|
        community.public_send(name).attach(io: File.open(picture), filename: 'mark.jpg', content_type: 'image/jpeg')
      end
    end
  end

  def hosted_event(community)
    create(:better_together_event, privacy: 'public', starts_at: 3.days.from_now, ends_at: 3.days.from_now + 2.hours,
                                   event_hosts_attributes: [{ host_type: 'BetterTogether::Community',
                                                              host_id: community.id }])
  end

  def page_for(path)
    get path
    response.body
  end

  before { configure_host_platform }

  describe 'event card host mention' do
    it 'shows a logo as a tile, with no round avatar for the same host', :aggregate_failures do
      event = hosted_event(community_with(:logo, :profile_image))
      body = page_for(better_together.events_path(locale: I18n.default_locale))
      card = body[/id="event_#{event.id}".*\z/m]

      expect(card).to include('community-mark-tile')
      expect(card).not_to match(/profile-image[^"]*event-host-avatar/)
    end

    it 'shows the round profile image when the community has no logo', :aggregate_failures do
      event = hosted_event(community_with(:profile_image))
      body = page_for(better_together.events_path(locale: I18n.default_locale))

      expect(body[/id="event_#{event.id}".*\z/m]).to match(/profile-image[^"]*event-host-avatar/)
      expect(body).not_to include('community-mark-tile')
    end
  end

  describe 'host picker' do
    it 'shows the existing host\'s logo tile in the edit form', :aggregate_failures do
      event = hosted_event(community_with(:logo))
      login('manager@example.test', 'SecureTest123!@#')
      body = page_for(better_together.edit_event_path(event, locale: I18n.default_locale))

      expect(body).to include('community-mark-tile')
    end
  end

  describe 'community chip' do
    it 'shows the logo tile on a post card', :aggregate_failures do
      community = community_with(:logo)
      create(:better_together_post, community:, privacy: 'public', published_at: 1.day.ago)
      body = page_for(better_together.posts_path(locale: I18n.default_locale))

      expect(body[%r{class="community-chip.*?</a>}m]).to include('community-mark-tile')
    end
  end
end
